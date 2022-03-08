// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

error ApprovalCallerNotOwnerNorApproved();
error ApprovalQueryForNonexistentToken();
error ApproveToCaller();
error ApprovalToCurrentOwner();
error BalanceQueryForZeroAddress();
error MintedQueryForZeroAddress();
error MintToZeroAddress();
error MintZeroQuantity();
error OwnerIndexOutOfBounds();
error OwnerQueryForNonexistentToken();
error TokenIndexOutOfBounds();
error TransferCallerNotOwnerNorApproved();
error TransferFromIncorrectOwner();
error TransferToNonERC721ReceiverImplementer();
error TransferToZeroAddress();
error URIQueryForNonexistentToken();
error InsufficientEtherValue();
error NumberOfMintExceedsLimit();

/**
 * @title FekiraUniverse contract
 * @dev Extends ERC721A implementation
 */
contract FekiraUniverse is Context, Ownable, ERC165, IERC721, IERC721Metadata, IERC721Enumerable {
    using Address for address;
    using Strings for uint256;
    using SafeMath for uint16;
    using SafeMath for uint256;

    struct TokenOwnership {
        // The address of the owner.
        address addr;
        // Keeps track of the start time of ownership with minimal overhead for tokenomics.
        uint64 startTimestamp;
    }

    struct AddressData {
        // Realistically, 2**64-1 is more than enough.
        uint64 balance;
        // Keeps track of mint count with minimal overhead for tokenomics.
        uint64 numberMinted;
        uint16 numberMintedOfWhitelist;
        uint16 numberMintedOfSales;
    }

    enum MintsType {
        Whitelist,
        PublicSale
    }

    // The tokenId of the next token to be minted.
    uint256 internal _currentIndex;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Token base uri
    string private _baseTokenURI = "https://p4010183-u833-067a4df9.app.run.fish/api/v1/unpack/"; // test

    // Mapping from token ID to ownership details
    // An empty struct value does not necessarily mean the token is unowned. See ownershipOf implementation for details.
    mapping(uint256 => TokenOwnership) internal _ownerships;

    // Mapping owner address to address data
    mapping(address => AddressData) private _addressData;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    bytes32 public immutable hashOfLaunchMetadataList;
    string public launchMetadataListURL;
    address public immutable randomnessRevealer;
    bool public saleIsActive = true; // test

    uint256 public constant MAX_SUPPLY = 10000;
    uint16 public constant MAX_WHITE_LIST_MINTING_PER_USERS = 2;
    uint16 public constant MAX_PUBLIC_SALES_MINTING_PER_USERS = 2;
    address public constant WHITELIST_SIGNERS = 0x86DB88892459F98e3D4337B75aABd7E3D2734328;

    uint256 public constant MINTING_PRICE = 0.0000666 ether; // 0.08

    constructor(
        string memory name_,
        string memory symbol_,
        address randomnessRevealer_,
        bytes32 hashOfLaunchMetadataList_
    ) {
        _name = name_;
        _symbol = symbol_;
        hashOfLaunchMetadataList = hashOfLaunchMetadataList_;
        randomnessRevealer = randomnessRevealer_;
    }

    uint256 private _randomOffset = 0;
    uint256 private _launchCollectionSize = 0;

    function getRandomOffset() external view returns (uint256) {
        return _randomOffset;
    }

    /**
     * @notice Total number of tokens minted at reveal
     */
    function getLaunchCollectionSize() external view returns (uint256) {
        return _launchCollectionSize;
    }

    /**
     * @notice Returns the total number of tokens minted by the user (public sale)
     */
    function getNumberMintedOfSales(address owner) public view returns (uint16) {
        return _addressData[owner].numberMintedOfSales;
    }

    /**
     * @notice Returns the total number of tokens minted by the user (whitelist)
     */
    function getNumberMintedOfWhitelist(address owner) public view returns (uint16) {
        return _addressData[owner].numberMintedOfWhitelist;
    }

    /**
     * @notice Get mint information
     * @param user user address
     * @param mintsType 0: whitelist, 1: public sale
     * @return _totalSupply Current supply
     * @return maxSupply Max supply
     * @return mintingPrice The unit price of mint one (wei)
     * @return maxMintingPerUsersMintsType The maximum mint amount of the user under the specified mint type
     * @return numberMintedOfUserMintsType The number of mints the user has mint under the specified mint type
     */
    function getMintingInfo(address user, MintsType mintsType)
        external
        view
        returns (
            uint256 _totalSupply,
            uint256 maxSupply,
            uint256 mintingPrice,
            uint16 maxMintingPerUsersMintsType,
            uint16 numberMintedOfUserMintsType
        )
    {
        if (mintsType == MintsType.Whitelist) {
            return (
                totalSupply(),
                MAX_SUPPLY,
                MINTING_PRICE,
                MAX_WHITE_LIST_MINTING_PER_USERS,
                getNumberMintedOfSales(user)
            );
        } else if (mintsType == MintsType.PublicSale) {
            return (
                totalSupply(),
                MAX_SUPPLY,
                MINTING_PRICE,
                MAX_PUBLIC_SALES_MINTING_PER_USERS,
                getNumberMintedOfWhitelist(user)
            );
        }
    }

    function revealLaunchRandomness(uint256 randomOffset_, string memory launchMetadataListURL_) external {
        require(msg.sender == randomnessRevealer, "not allowed");
        require(_randomOffset == 0 && _launchCollectionSize == 0, "cannot reveal twice");
        _launchCollectionSize = totalSupply();
        require(_launchCollectionSize != 0, "supply cannot be 0");
        _randomOffset = randomOffset_ % _launchCollectionSize;
        launchMetadataListURL = launchMetadataListURL_;
    }

    /**
     * @notice Convert token external id (id after reveal) to internal id (id before reveal).
     */
    function externalTokenIdToInternalTokenId(uint256 externalTokenId) public view returns (uint256) {
        return tokenIdConverter(externalTokenId + _randomOffset);
    }

    /**
     * @notice Convert token internal id (id before reveal) to external id (id after reveal).
     */
    function internalTokenIdToExternalTokenId(uint256 internalTokenId) public view returns (uint256) {
        return tokenIdConverter(internalTokenId + _launchCollectionSize - _randomOffset);
    }

    function tokenIdConverter(uint256 _tokenIdWithOffset) private view returns (uint256) {
        if (_tokenIdWithOffset >= _launchCollectionSize) {
            return _tokenIdWithOffset - _launchCollectionSize;
        }
        return _tokenIdWithOffset;
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _currentIndex;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view override returns (uint256) {
        if (index >= totalSupply()) revert TokenIndexOutOfBounds();
        return internalTokenIdToExternalTokenId(index);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     * This read function is O(totalSupply). If calling from a separate contract, be sure to test gas first.
     * It may also degrade with extremely large collection sizes (e.g >> 10000), test for your use case.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
        if (index >= balanceOf(owner)) revert TokenIndexOutOfBounds();
        uint256 numMintedSoFar = totalSupply();
        uint256 tokenIdsIdx;
        address currOwnershipAddr;

        // Counter overflow is impossible as the loop breaks when uint256 i is equal to another uint256 numMintedSoFar.
        unchecked {
            for (uint256 i; i < numMintedSoFar; i++) {
                TokenOwnership memory ownership = _ownerships[i];
                if (ownership.addr != address(0)) {
                    currOwnershipAddr = ownership.addr;
                }
                if (currOwnershipAddr == owner) {
                    if (tokenIdsIdx == index) {
                        return internalTokenIdToExternalTokenId(i);
                    }
                    tokenIdsIdx++;
                }
            }
        }

        revert("unable to get token of owner by index");
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        if (owner == address(0)) revert BalanceQueryForZeroAddress();
        return uint256(_addressData[owner].balance);
    }

    /**
     * @notice Returns the total number of tokens minted by the user
     */
    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function _numberMinted(address owner) internal view returns (uint256) {
        if (owner == address(0)) revert MintedQueryForZeroAddress();
        return uint256(_addressData[owner].numberMinted);
    }

    /**
     * Gas spent here starts off proportional to the maximum mint batch size.
     * It gradually moves to O(1) as tokens get transferred around in the collection over time.
     */
    function ownershipOf(uint256 tokenId) internal view returns (TokenOwnership memory) {
        uint256 curr = tokenId;

        unchecked {
            if (curr < _currentIndex) {
                TokenOwnership memory ownership = _ownerships[curr];
                if (ownership.addr != address(0)) {
                    return ownership;
                }
                // Invariant:
                // There will always be an ownership that has an address and is not burned
                // before an ownership that does not have an address and is not burned.
                // Hence, curr will not underflow.
                while (true) {
                    curr--;
                    ownership = _ownerships[curr];
                    if (ownership.addr != address(0)) {
                        return ownership;
                    }
                }
            }
        }
        revert OwnerQueryForNonexistentToken();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return ownershipOf(tokenId).addr;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length != 0
                ? string(abi.encodePacked(baseURI, internalTokenIdToExternalTokenId(tokenId).toString()))
                : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public override {
        address owner = FekiraUniverse.ownerOf(tokenId);
        if (to == owner) revert ApprovalToCurrentOwner();

        if (_msgSender() != owner && !isApprovedForAll(owner, _msgSender())) {
            revert ApprovalCallerNotOwnerNorApproved();
        }

        _approve(to, tokenId, owner);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override returns (address) {
        if (!_exists(tokenId)) revert ApprovalQueryForNonexistentToken();
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public override {
        if (operator == _msgSender()) revert ApproveToCaller();

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        _transfer(from, to, tokenId);
        if (!_checkOnERC721Received(from, to, tokenId, _data)) {
            revert TransferToNonERC721ReceiverImplementer();
        }
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId < _currentIndex;
    }

    function splitSignature(bytes memory sig)
        private
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function verify(
        address _to,
        uint256 _amount,
        uint256 _userCurrentNumberMinted,
        bytes memory signature
    ) private pure returns (bool) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

        return
            WHITELIST_SIGNERS ==
            ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        keccak256(abi.encodePacked(_to, _amount, _userCurrentNumberMinted))
                    )
                ),
                v,
                r,
                s
            );
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Withdrawable amount is 0");
        payable(msg.sender).transfer(balance);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Toggle public sale status
     */
    function toggleSaleStatus() external onlyOwner {
        saleIsActive = !saleIsActive;
    }

    /**
     * @notice Mints Fekira Universe tokens
     */
    function mintFU(uint256 quantity) external payable {
        require(saleIsActive, "public sale must have started");
        if ((_addressData[msg.sender].numberMintedOfSales.add(quantity)) > MAX_PUBLIC_SALES_MINTING_PER_USERS)
            revert NumberOfMintExceedsLimit();
        if (msg.value < (MINTING_PRICE.mul(quantity))) revert InsufficientEtherValue();
        _addressData[msg.sender].numberMintedOfSales += uint16(quantity);
        _safeMint(msg.sender, quantity);
    }

    /**
     * @dev (Signed trusted) mints `quantity` tokens and transfers them to `to`.
     *
     * `userCurrentNumberMinted` never goes down for a given user, so signatures cannot be reused.
     */
    function mintTokensWhitelist(
        address to,
        uint256 quantity,
        uint256 userCurrentNumberMinted,
        bytes memory signature
    ) external payable {
        require(verify(to, quantity, userCurrentNumberMinted, signature), "signature invalid");
        require(_addressData[to].numberMinted == userCurrentNumberMinted, "number minted invalid");
        if ((_addressData[to].numberMintedOfWhitelist.add(quantity)) > MAX_WHITE_LIST_MINTING_PER_USERS)
            revert NumberOfMintExceedsLimit();
        if (msg.value < (MINTING_PRICE.mul(quantity))) revert InsufficientEtherValue();
        _addressData[to].numberMintedOfWhitelist += uint16(quantity);
        _safeMint(to, quantity);
    }

    function _safeMint(address to, uint256 quantity) internal {
        _safeMint(to, quantity, "");
    }

    /**
     * @dev Safely mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called for each safe transfer.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    ) internal {
        _mint(to, quantity, _data, true);
    }

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event.
     */
    function _mint(
        address to,
        uint256 quantity,
        bytes memory _data,
        bool safe
    ) internal {
        require((totalSupply().add(quantity)) <= MAX_SUPPLY, "Exceed max supply");

        uint256 startTokenId = _currentIndex;
        if (to == address(0)) revert MintToZeroAddress();
        if (quantity == 0) revert MintZeroQuantity();

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are incredibly unrealistic.
        // balance or numberMinted overflow if current value of either + quantity > 1.8e19 (2**64) - 1
        // updatedIndex overflows if _currentIndex + quantity > 1.2e77 (2**256) - 1
        unchecked {
            _addressData[to].balance += uint64(quantity);
            _addressData[to].numberMinted += uint64(quantity);

            _ownerships[startTokenId].addr = to;
            _ownerships[startTokenId].startTimestamp = uint64(block.timestamp);

            uint256 updatedIndex = startTokenId;
            uint256 end = updatedIndex + quantity;

            if (safe && to.isContract()) {
                do {
                    emit Transfer(address(0), to, updatedIndex);
                    if (!_checkOnERC721Received(address(0), to, updatedIndex++, _data)) {
                        revert TransferToNonERC721ReceiverImplementer();
                    }
                } while (updatedIndex != end);
                // Reentrancy protection
                if (_currentIndex != startTokenId) revert();
            } else {
                do {
                    emit Transfer(address(0), to, updatedIndex++);
                } while (updatedIndex != end);
            }
            _currentIndex = updatedIndex;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) private {
        TokenOwnership memory prevOwnership = ownershipOf(tokenId);

        bool isApprovedOrOwner = (_msgSender() == prevOwnership.addr ||
            isApprovedForAll(prevOwnership.addr, _msgSender()) ||
            getApproved(tokenId) == _msgSender());

        if (!isApprovedOrOwner) revert TransferCallerNotOwnerNorApproved();
        if (prevOwnership.addr != from) revert TransferFromIncorrectOwner();
        if (to == address(0)) revert TransferToZeroAddress();

        _beforeTokenTransfers(from, to, tokenId, 1);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId, prevOwnership.addr);

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as tokenId would have to be 2**256.
        unchecked {
            _addressData[from].balance -= 1;
            _addressData[to].balance += 1;

            _ownerships[tokenId].addr = to;
            _ownerships[tokenId].startTimestamp = uint64(block.timestamp);

            // If the ownership slot of tokenId+1 is not explicitly set, that means the transfer initiator owns it.
            // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
            uint256 nextTokenId = tokenId + 1;
            if (_ownerships[nextTokenId].addr == address(0)) {
                // This will suffice for checking _exists(nextTokenId),
                // as a burned slot cannot contain the zero address.
                if (nextTokenId < _currentIndex) {
                    _ownerships[nextTokenId].addr = prevOwnership.addr;
                    _ownerships[nextTokenId].startTimestamp = prevOwnership.startTimestamp;
                }
            }
        }

        emit Transfer(from, to, tokenId);
        _afterTokenTransfers(from, to, tokenId, 1);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(
        address to,
        uint256 tokenId,
        address owner
    ) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert TransferToNonERC721ReceiverImplementer();
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before a set of serially-ordered token ids are about to be transferred. This includes minting.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Hook that is called after a set of serially-ordered token ids have been transferred. This includes
     * minting.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}
}
