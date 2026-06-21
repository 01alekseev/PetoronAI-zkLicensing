// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/*
Copyright (c) Ivan Alekseev

Licensed under the PetoronAI Community License (PCL)
or a valid PetoronAI Commercial License.
*/

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract PetoronVaultKeyNFT {
    string public constant name = "Petoron Vault Key";
    string public constant symbol = "PTKEY";

    uint256 public constant KEY_ONE = 1;
    uint256 public constant KEY_TWO = 2;

    mapping(uint256 => address) private owners;
    mapping(address => uint256) private balances;
    mapping(uint256 => address) private tokenApprovals;
    mapping(address => mapping(address => bool)) private operatorApprovals;
    mapping(uint256 => bool) public locked;

    address public constant VAULT_CONTRACT_PLACEHOLDER =
        0x0000000000000000000000000000000000000002;

    address public immutable initializer;
    address public vault;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    error ZeroAddress();
    error InvalidTokenId();
    error SameKeyHolder();
    error NotOwner();
    error NotApproved();
    error ReceiverRejected();
    error Locked();
    error NotVault();
    error ApprovalsDisabled();
    error PlaceholderAddress();
    error NotInitializer();

    constructor(address initialHolder) {
        if (initialHolder == address(0)) {
            revert ZeroAddress();
        }

        initializer = initialHolder;

        owners[KEY_ONE] = initialHolder;
        owners[KEY_TWO] = initialHolder;

        balances[initialHolder] = 2;

        emit Transfer(address(0), initialHolder, KEY_ONE);
        emit Transfer(address(0), initialHolder, KEY_TWO);
    }

    function setVault(address vaultAddress) external {
        if (msg.sender != initializer) {
            revert NotInitializer();
        }

        if (vault != address(0)) {
            revert NotVault();
        }

        if (vaultAddress == address(0)) {
            revert ZeroAddress();
        }

        if (vaultAddress == VAULT_CONTRACT_PLACEHOLDER) {
            revert PlaceholderAddress();
        }

        vault = vaultAddress;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x80ac58cd;
    }

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) {
            revert ZeroAddress();
        }

        return balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = owners[tokenId];

        if (owner == address(0)) {
            revert InvalidTokenId();
        }

        return owner;
    }

    function approve(address, uint256) external pure {
        revert ApprovalsDisabled();
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        ownerOf(tokenId);

        return tokenApprovals[tokenId];
    }

    function setApprovalForAll(address, bool) external pure {
        revert ApprovalsDisabled();
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (to == address(0)) {
            revert ZeroAddress();
        }

        address owner = ownerOf(tokenId);

        if (owner != from) {
            revert NotOwner();
        }

        if (!_isApprovedOrOwner(msg.sender, tokenId, owner)) {
            revert NotApproved();
        }

        if (locked[tokenId]) {
            revert Locked();
        }

        if (tokenId == KEY_ONE && owners[KEY_TWO] == to) {
            revert SameKeyHolder();
        }

        if (tokenId == KEY_TWO && owners[KEY_ONE] == to) {
            revert SameKeyHolder();
        }

        delete tokenApprovals[tokenId];

        unchecked {
            balances[from] -= 1;
            balances[to] += 1;
        }

        owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public {
        transferFrom(from, to, tokenId);

        if (to.code.length != 0) {
            bytes4 result = IERC721Receiver(to).onERC721Received(
                msg.sender,
                from,
                tokenId,
                data
            );

            if (result != IERC721Receiver.onERC721Received.selector) {
                revert ReceiverRejected();
            }
        }
    }

    function setLocked(uint256 tokenId, bool value) external {
        if (msg.sender != vault) {
            revert NotVault();
        }

        ownerOf(tokenId);

        locked[tokenId] = value;
    }

    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId,
        address owner
    ) private view returns (bool) {
        return spender == owner ||
            tokenApprovals[tokenId] == spender ||
            operatorApprovals[owner][spender];
    }
}
