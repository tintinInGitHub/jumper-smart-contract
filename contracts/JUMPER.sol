// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;


import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
 
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Import axelar libraries
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";

contract JUMPER is ERC721, ERC721Burnable, Ownable, AxelarExecutable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    using Address for address;
    using SafeERC20 for IERC20;

    Counters.Counter private supply;

    string public uriPrefix = "";
    string public uriSuffix = ".json";
    string public initChainName;

    struct statusBridge {
        uint256 avax;
        uint256 fantom;
        uint256 matic;
    }

    struct NFTStatus {
        uint256 level;
        uint256 point;
        uint256 born;
        uint256 codePic;
        statusBridge countBridge;
    }

    // Mapping from token ID to NFT status
    mapping(uint256 => NFTStatus) private _status;

    // Store gas service
    IAxelarGasService public immutable gasService;
    mapping(bytes32 => string) public destinationAddressMapping;

    // Receive gateway and gas service
    constructor(
        IAxelarGateway _gateway,
        IAxelarGasService _gasService,
         string memory _initChainName
    ) ERC721("JUMPER", "JUP") AxelarExecutable(address(_gateway)) {
        gasService = _gasService;
        initChainName = _initChainName;
    }

    function nftStatus(uint256 _tokenId) external view returns (uint256 level,uint256 point,uint256 born,uint256 codePic ,uint256 avax, uint256 fantom,uint256 matic) {
      return (_status[_tokenId].level,_status[_tokenId].point,_status[_tokenId].born,_status[_tokenId].codePic,_status[_tokenId].countBridge.avax,_status[_tokenId].countBridge.fantom,_status[_tokenId].countBridge.matic);
    }

    function stringCompare(string memory s1, string memory s2) private  pure returns(bool) {
      if (keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2))){
        return  true;
      }else {
        return  false;
      }
    }

    
    function safeMint(address to) public {
       supply.increment();
      _safeMint(to,  supply.current());
      if(stringCompare(initChainName,"Avalanche")){
        _status[supply.current()].born = 1;
        _status[supply.current()].codePic = 1;
      }else if(stringCompare(initChainName,"Fantom")){
        _status[supply.current()].born = 2;
        _status[supply.current()].codePic = 2;
      }else if(stringCompare(initChainName,"Polygon")){
        _status[supply.current()].born = 3;
        _status[supply.current()].codePic = 3;
      }
    }

    function _baseURI() internal view virtual override returns (string memory) {
      return uriPrefix;
    }

    function setUriPrefix(string memory _uriPrefix) external onlyOwner {
      uriPrefix = _uriPrefix;
    }

  
    function setUriSuffix(string memory _uriSuffix) external onlyOwner {
      uriSuffix = _uriSuffix;
    }

    function tokenURI(uint256 _tokenId)
      public
      view
      virtual
      override
      returns (string memory)
    {
      require(
        _exists(_tokenId),
        "ERC721Metadata: URI query for nonexistent token"
      );


      string memory currentBaseURI = _baseURI();
      return bytes(currentBaseURI).length > 0
          ? string(abi.encodePacked(currentBaseURI,  _status[_tokenId].codePic.toString(), uriSuffix))
          : "";
    }

  
    function totalSupply() external view returns (uint256) {
      return supply.current();
    }


    // Link contract in the destination chain
    event SetDestinationMapping(string chainName, string contractAddress);
    function setDestinationMapping(string calldata chainName, string calldata contractAddress) public onlyOwner {
        destinationAddressMapping[keccak256(abi.encode(chainName))] = contractAddress;
        emit SetDestinationMapping(chainName, contractAddress);
    }

    event Lock(string destinationChain, string destinationAddress, uint256 tokenId);

    // Send message
    function bridge(
        string calldata destinationChain,
        uint256 tokenId
    ) external payable {
        // TODO: Fetch destinationAddress from destinationChain
        string memory destinationAddress = destinationAddressMapping[keccak256(abi.encode(destinationChain))];

        if (bytes(destinationAddress).length == 0) {
            revert("Destination zero");
        }

        // TODO: Lock (Burn) token in the source chain
        _burn(tokenId);

        // TODO: ABI encode payload
        bytes memory payload = abi.encode(msg.sender, _status[tokenId] );

        // TODO: Pay gas fee to gas receiver contract
        if (msg.value > 0) {
            gasService.payNativeGasForContractCall{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
        }

        // TODO: Submit a cross-chain message passing transaction
        gateway.callContract(destinationChain, destinationAddress, payload);

        // TODO: Emit event
        emit Lock(destinationChain, destinationAddress, tokenId);
    }

    // Receive message
    event Unlock(address indexed to, uint256 amount);

    function _execute(
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes calldata payload
    ) internal override {
        // TODO: Validate sourceChain and sourceAddress
        require(
            keccak256(abi.encode(sourceAddress)) == keccak256(abi.encode( destinationAddressMapping[
                keccak256(abi.encode(sourceChain))
            ] )),
            "Forbidden"
        );

        // TODO: Decode payload
        (address to, NFTStatus memory statusNft) = abi.decode(payload, (address, NFTStatus));

        // TODO: Unlock (Mint) token
        supply.increment();
        _mint(to, supply.current());
        setNewStatusNFT(supply.current(),statusNft);
        if(_status[supply.current()].level == 0 && totalBridge(supply.current())>= 4){
          evol(supply.current(),1);
        }
        if(_status[supply.current()].level == 1 && totalBridge(supply.current())>= 7){
          evol(supply.current(),2);
        }
     
    }


      if(stringCompare(initChainName,"Avalanche")){
        statusNft.countBridge.avax += 1;
      }else if(stringCompare(initChainName,"Fantom")){
         statusNft.countBridge.fantom += 1;
      }else if(stringCompare(initChainName,"Polygon")){
        statusNft.countBridge.matic += 1;
      }

      _status[tokenId].countBridge.avax = statusNft.countBridge.avax;
      _status[tokenId].countBridge.fantom = statusNft.countBridge.fantom;
      _status[tokenId].countBridge.matic = statusNft.countBridge.matic;
    }

    function evol(uint256 tokenId,uint256 levelEvol) internal {
      if(levelEvol ==1){
        if(_status[tokenId].born == 1 ){
          findMaxIndex(tokenId) == 0 ?  _status[tokenId].codePic = 1100 : _status[tokenId].codePic = 1011;
        } else if(_status[tokenId].born == 2 ){
          findMaxIndex(tokenId) == 1 ? _status[tokenId].codePic = 1010 : _status[tokenId].codePic = 1101;
        } else if(_status[tokenId].born == 3 ){
          findMaxIndex(tokenId) == 2 ? _status[tokenId].codePic = 1001 : _status[tokenId].codePic = 1110;
        }
      }
      else if(levelEvol==2){
         if(_status[tokenId].born == 1 ){
          findMaxIndex(tokenId) == 0 ?  _status[tokenId].codePic = 2100 : _status[tokenId].codePic = 2011;
        } else if(_status[tokenId].born == 2 ){
          findMaxIndex(tokenId) == 1 ? _status[tokenId].codePic = 2010 : _status[tokenId].codePic = 2101;
        } else if(_status[tokenId].born == 3 ){
          findMaxIndex(tokenId) == 2 ? _status[tokenId].codePic = 2001 : _status[tokenId].codePic = 2110;
        }
      }
    }

    
    function findMaxIndex(uint256 tokenId) public view returns(uint256){
        uint256[] memory numbers = new uint256[](3);

        numbers[0] =  _status[tokenId].countBridge.avax;
        numbers[1] =  _status[tokenId].countBridge.fantom;
        numbers[2] =  _status[tokenId].countBridge.matic;

        uint256 maxIndex = 0;
        uint256 maxValue = numbers[0]; 
        uint256 i =1;

        while( i < numbers.length) {
          if(numbers[i] > maxValue){
            maxValue = numbers[i];
            maxIndex = i;
          }
          i++;
        }
        return maxIndex;
    }

    function totalBridge(uint256 tokenId) internal view returns(uint256 ) {
       return _status[tokenId].countBridge.avax + _status[tokenId].countBridge.fantom + _status[tokenId].countBridge.matic;
    }

}

