//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract CapitalistPigs is ERC721, Ownable {
    using Strings for uint256;

    enum MintStatus { Closed, Presale, Public }

    struct TierInfo {
        uint price;
        MintStatus mintStatus;
        uint minId;
        uint nextId;
        uint maxId;
    }
    mapping(uint => TierInfo) tiers;
    uint nextTier;

    // A counter to allow us to keep fresh presale buyers list for arbitrary future mints.
    uint currentPresale;
    
    // currrentPresale => address => hasMinted
    mapping(uint => mapping(address => bool)) presaleBuyers;
    mapping(uint => bytes32) presaleRoot;

    address payable devWallet;
    string baseURI;
    
    uint royaltyRate; 
    uint constant royaltyRateDivisor = 100_000;
    address payable royaltyWallet; 

    constructor (
        string memory _baseURI,
        address payable _royaltyWallet,
        address payable _devWallet
    ) ERC721("Capitalist Pigs", "PIGS") {
        baseURI = _baseURI;
        royaltyRate = 10_000;
        royaltyWallet = _royaltyWallet;
        devWallet = _devWallet;

        tiers[nextTier++] = TierInfo({
            price: 5 ether,
            mintStatus: MintStatus.Public,
            minId: 0,
            nextId: 0,
            maxId: 49
        });
    }

    // MINTING FUNCTIONS //
    
    function mintPresale(uint _edition, bytes32[] calldata _proof) public payable {
        TierInfo storage tier = tiers[_edition];
        require(tier.mintStatus == MintStatus.Presale, "presale minting closed");
        require(presaleBuyers[currentPresale][msg.sender] == false, 'already minted');
        require(MerkleProof.verify(_proof, presaleRoot[currentPresale], keccak256(abi.encodePacked(msg.sender))), "invalid merkle proof");
        presaleBuyers[currentPresale][msg.sender] = true;
        _mintTokens(tier, 1);
    }

    function mintPublic(uint _edition, uint _quantity) public payable {
        TierInfo storage tier = tiers[_edition];
        require(tier.mintStatus == MintStatus.Public, "public minting closed");
        _mintTokens(tier, _quantity);
    }

    function _mintTokens(TierInfo storage tier, uint _quantity) internal {
        require(msg.value == _quantity * tier.price, "incorrect value");
        require(tier.nextId + _quantity - 1 <= tier.maxId, "max id reached");
        for (uint i = 0; i < _quantity; i++) {
            _safeMint(msg.sender, tier.nextId++);
        }
    }

    function ownerMint(uint _edition, address _to) external onlyOwner {
        TierInfo storage tier = tiers[_edition];
        require(tier.nextId <= tier.maxId, "max id reached");
        _safeMint(_to, tier.nextId++);
    }

    // VIEWS //

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    function getTierInfo(uint _edition) public view returns (TierInfo memory) {
        return tiers[_edition];
    }

    function isPigInTier(uint _tokenId, uint _edition) public view returns (bool) {
        TierInfo memory tier = tiers[_edition];
        return (_tokenId >= tier.minId && _tokenId < tier.nextId);
    }

    function isOwnerInTier(address _owner, uint _tokenId, uint _edition) public view returns (bool) {
        return (ownerOf(_tokenId) == _owner && isPigInTier(_tokenId, _edition));
    }

    // CREATE & UPDATE TIERS //

    function createNewTier(uint _price, MintStatus _mintStatus, uint _minId, uint _maxId) external onlyOwner {
        require(tiers[nextTier - 1].maxId < _minId, "minId must be higher than prev tier maxId");
        tiers[nextTier++] = TierInfo({
            price: _price,
            mintStatus: _mintStatus,
            minId: _minId,
            nextId: _minId,
            maxId: _maxId
        });
    }

    function setTierInfo(uint _edition, MintStatus _status, uint _price, uint _maxId) external onlyOwner {
        TierInfo memory oldTierInfo = tiers[_edition];
        require(tiers[_edition + 1].minId == 0 || _maxId < tiers[_edition + 1].minId, "overlapping with next tier");
        tiers[_edition] = TierInfo({
            price: _price,
            mintStatus: _status,
            minId: oldTierInfo.minId,
            nextId: oldTierInfo.nextId,
            maxId: _maxId
        });        
    }

    // ADMIN //

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function setDevWallet(address payable _devWallet) external onlyOwner {
        devWallet = _devWallet;
    }

    function startNewPresale(bytes32 _root) external onlyOwner {
        unchecked {
            currentPresale++;
        }
        presaleRoot[currentPresale] = _root;
    }

    function withdrawEth(address payable _addr) external onlyOwner {
        uint devPayout = address(this).balance / 10;
        devWallet.transfer(devPayout);
        _addr.transfer(address(this).balance);
    }

    function withdrawToken(address token, address _addr) external onlyOwner {
        uint balance = IERC20(token).balanceOf(address(this));
        uint devPayout = balance / 10;
        IERC20(token).transfer(devWallet, devPayout);
        IERC20(token).transfer(_addr, balance - devPayout);
    }

    // EIP 2981 ROYALTIES //

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        require(_exists(_tokenId), "nonexistant token");
        uint amountToPay = _salePrice * royaltyRate / royaltyRateDivisor;
        return (royaltyWallet, amountToPay);
    }

    function updateRoyaltyRate(uint256 _rate) public onlyOwner {
        royaltyRate = _rate;
    }

    function updateRoyaltyWallet(address payable _wallet) public onlyOwner {
        royaltyWallet = _wallet;
    }
}