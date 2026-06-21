// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/*
Copyright (c) Ivan Alekseev

Licensed under the PetoronAI Community License (PCL)
or a valid PetoronAI Commercial License.
*/

interface IPetoronVaultKeyNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
    function setLocked(uint256 tokenId, bool value) external;
}

contract PetoronEthVault {
    uint256 public constant KEY_ONE = 1;
    uint256 public constant KEY_TWO = 2;

    IPetoronVaultKeyNFT public immutable keyNFT;

    uint256 public constant WITHDRAW_DELAY_BLOCKS = 7200;
    uint256 public constant REQUEST_EXPIRE_BLOCKS = 28800;
    uint256 public constant EXECUTE_WINDOW_BLOCKS = 7200;

    uint256 public nextRequestId = 1;
    uint256 public depositCount;
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;

    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => address) public commitmentPayers;
    mapping(bytes32 => uint256) public commitmentAmounts;
    mapping(bytes32 => uint256) public commitmentBlocks;

    mapping(uint256 => WithdrawRequest) public withdrawRequests;
    mapping(uint256 => uint256) public activeRequestByToken;

    struct WithdrawRequest {
        address requester;
        uint256 requesterTokenId;
        address approver;
        uint256 approverTokenId;
        address payable to;
        uint256 amount;
        uint256 createdAtBlock;
        uint256 approvedAtBlock;
        bool approved;
        bool executed;
        bool cancelled;
    }

    event Deposit(
        address indexed payer,
        bytes32 indexed commitment,
        uint256 amount,
        uint256 indexed depositId
    );

    event WithdrawRequested(
        uint256 indexed requestId,
        address indexed requester,
        uint256 indexed requesterTokenId,
        address to,
        uint256 amount
    );

    event WithdrawApproved(
        uint256 indexed requestId,
        address indexed approver,
        uint256 indexed approverTokenId
    );

    event WithdrawExecuted(
        uint256 indexed requestId,
        address indexed to,
        uint256 amount
    );

    event WithdrawCancelled(uint256 indexed requestId);
    event ExpiredWithdrawReleased(uint256 indexed requestId);

    error ZeroAddress();
    error ZeroAmount();
    error ZeroCommitment();
    error DuplicateCommitment();
    error InvalidValue();
    error InvalidKey();
    error NotKeyHolder();
    error SameKeyHolder();
    error RequestNotFound();
    error AlreadyApproved();
    error AlreadyExecuted();
    error AlreadyCancelled();
    error WrongApproverKey();
    error ApprovalRequired();
    error TimelockActive();
    error RequestExpired();
    error RequestNotExpired();
    error ExecuteWindowExpired();
    error InsufficientBalance();
    error TransferFailed();
    error ActiveRequestExists();
    error BadPolicy();

    constructor(address keyNFTAddress) {
        if (keyNFTAddress == address(0)) {
            revert ZeroAddress();
        }

        keyNFT = IPetoronVaultKeyNFT(keyNFTAddress);
    }

    function deposit(bytes32 commitment) external payable {
        if (msg.value == 0) {
            revert ZeroAmount();
        }

        if (commitment == bytes32(0)) {
            revert ZeroCommitment();
        }

        if (commitments[commitment]) {
            revert DuplicateCommitment();
        }

        depositCount += 1;
        totalDeposited += msg.value;

        commitments[commitment] = true;
        commitmentPayers[commitment] = msg.sender;
        commitmentAmounts[commitment] = msg.value;
        commitmentBlocks[commitment] = block.number;

        emit Deposit(
            msg.sender,
            commitment,
            msg.value,
            depositCount
        );
    }

    function requestWithdraw(
        uint256 requesterTokenId,
        address payable to,
        uint256 amount
    ) external returns (uint256 requestId) {
        if (!_isValidKey(requesterTokenId)) {
            revert InvalidKey();
        }

        if (to == address(0)) {
            revert ZeroAddress();
        }

        if (amount == 0) {
            revert ZeroAmount();
        }

        if (amount > address(this).balance) {
            revert InsufficientBalance();
        }

        if (keyNFT.ownerOf(requesterTokenId) != msg.sender) {
            revert NotKeyHolder();
        }

        uint256 approverTokenId = _otherKey(requesterTokenId);
        address approver = keyNFT.ownerOf(approverTokenId);

        if (approver == msg.sender) {
            revert SameKeyHolder();
        }

        _requireNoBlockingActiveRequest(requesterTokenId);
        _requireNoBlockingActiveRequest(approverTokenId);

        requestId = nextRequestId;
        nextRequestId = requestId + 1;

        activeRequestByToken[requesterTokenId] = requestId;
        activeRequestByToken[approverTokenId] = requestId;

        withdrawRequests[requestId] = WithdrawRequest({
            requester: msg.sender,
            requesterTokenId: requesterTokenId,
            approver: address(0),
            approverTokenId: approverTokenId,
            to: to,
            amount: amount,
            createdAtBlock: block.number,
            approvedAtBlock: 0,
            approved: false,
            executed: false,
            cancelled: false
        });

        keyNFT.setLocked(requesterTokenId, true);
        keyNFT.setLocked(approverTokenId, true);

        emit WithdrawRequested(
            requestId,
            msg.sender,
            requesterTokenId,
            to,
            amount
        );
    }

    function approveWithdraw(uint256 requestId) external {
        WithdrawRequest storage request = withdrawRequests[requestId];

        _requireExisting(request);

        if (request.cancelled) {
            revert AlreadyCancelled();
        }

        if (request.executed) {
            revert AlreadyExecuted();
        }

        if (request.approved) {
            revert AlreadyApproved();
        }

        if (block.number > request.createdAtBlock + REQUEST_EXPIRE_BLOCKS) {
            revert RequestExpired();
        }

        if (keyNFT.ownerOf(request.requesterTokenId) != request.requester) {
            revert NotKeyHolder();
        }

        if (keyNFT.ownerOf(request.approverTokenId) != msg.sender) {
            revert WrongApproverKey();
        }

        if (msg.sender == request.requester) {
            revert SameKeyHolder();
        }

        request.approver = msg.sender;
        request.approvedAtBlock = block.number;
        request.approved = true;

        emit WithdrawApproved(
            requestId,
            msg.sender,
            request.approverTokenId
        );
    }

    function executeWithdraw(uint256 requestId) external {
        WithdrawRequest storage request = withdrawRequests[requestId];

        _requireExisting(request);

        if (request.cancelled) {
            revert AlreadyCancelled();
        }

        if (request.executed) {
            revert AlreadyExecuted();
        }

        if (!request.approved) {
            revert ApprovalRequired();
        }

        if (block.number < request.approvedAtBlock + WITHDRAW_DELAY_BLOCKS) {
            revert TimelockActive();
        }

        if (block.number > request.createdAtBlock + REQUEST_EXPIRE_BLOCKS) {
            revert RequestExpired();
        }

        if (
            block.number >
            request.approvedAtBlock + WITHDRAW_DELAY_BLOCKS + EXECUTE_WINDOW_BLOCKS
        ) {
            revert ExecuteWindowExpired();
        }

        if (keyNFT.ownerOf(request.requesterTokenId) != request.requester) {
            revert NotKeyHolder();
        }

        if (keyNFT.ownerOf(request.approverTokenId) != request.approver) {
            revert WrongApproverKey();
        }

        if (request.requester == request.approver) {
            revert SameKeyHolder();
        }

        if (keyNFT.ownerOf(KEY_ONE) == keyNFT.ownerOf(KEY_TWO)) {
            revert SameKeyHolder();
        }

        if (request.amount > address(this).balance) {
            revert InsufficientBalance();
        }

        request.executed = true;
        totalWithdrawn += request.amount;

        _releaseActive(
            requestId,
            request.requesterTokenId,
            request.approverTokenId
        );

        (bool ok, ) = request.to.call{value: request.amount}("");

        if (!ok) {
            revert TransferFailed();
        }

        emit WithdrawExecuted(requestId, request.to, request.amount);
    }

    function cancelWithdraw(uint256 requestId) external {
        WithdrawRequest storage request = withdrawRequests[requestId];

        _requireExisting(request);

        if (request.cancelled) {
            revert AlreadyCancelled();
        }

        if (request.executed) {
            revert AlreadyExecuted();
        }

        if (
            keyNFT.ownerOf(request.requesterTokenId) != msg.sender &&
            keyNFT.ownerOf(request.approverTokenId) != msg.sender
        ) {
            revert NotKeyHolder();
        }

        request.cancelled = true;

        _releaseActive(
            requestId,
            request.requesterTokenId,
            request.approverTokenId
        );

        emit WithdrawCancelled(requestId);
    }

    function releaseExpiredWithdraw(uint256 requestId) external {
        WithdrawRequest storage request = withdrawRequests[requestId];

        _requireExisting(request);

        if (request.cancelled) {
            revert AlreadyCancelled();
        }

        if (request.executed) {
            revert AlreadyExecuted();
        }

        if (block.number <= request.createdAtBlock + REQUEST_EXPIRE_BLOCKS) {
            revert RequestNotExpired();
        }

        request.cancelled = true;

        _releaseActive(
            requestId,
            request.requesterTokenId,
            request.approverTokenId
        );

        emit ExpiredWithdrawReleased(requestId);
    }

    function vaultBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function commitmentInfo(
        bytes32 commitment
    )
        external
        view
        returns (
            bool exists,
            address payer,
            uint256 amount,
            uint256 depositedAtBlock
        )
    {
        return (
            commitments[commitment],
            commitmentPayers[commitment],
            commitmentAmounts[commitment],
            commitmentBlocks[commitment]
        );
    }

    receive() external payable {
        revert InvalidValue();
    }

    fallback() external payable {
        revert InvalidValue();
    }

    function _requireNoBlockingActiveRequest(uint256 tokenId) private view {
        uint256 requestId = activeRequestByToken[tokenId];

        if (requestId == 0) {
            return;
        }

        WithdrawRequest storage request = withdrawRequests[requestId];

        if (
            !request.cancelled &&
            !request.executed &&
            block.number <= request.createdAtBlock + REQUEST_EXPIRE_BLOCKS
        ) {
            revert ActiveRequestExists();
        }
    }

    function _releaseActive(
        uint256 requestId,
        uint256 tokenA,
        uint256 tokenB
    ) private {
        if (activeRequestByToken[tokenA] == requestId) {
            activeRequestByToken[tokenA] = 0;
            keyNFT.setLocked(tokenA, false);
        }

        if (activeRequestByToken[tokenB] == requestId) {
            activeRequestByToken[tokenB] = 0;
            keyNFT.setLocked(tokenB, false);
        }
    }

    function _requireExisting(
        WithdrawRequest storage request
    ) private view {
        if (request.createdAtBlock == 0) {
            revert RequestNotFound();
        }
    }

    function _isValidKey(uint256 tokenId) private pure returns (bool) {
        return tokenId == KEY_ONE || tokenId == KEY_TWO;
    }

    function _otherKey(uint256 tokenId) private pure returns (uint256) {
        if (tokenId == KEY_ONE) {
            return KEY_TWO;
        }

        if (tokenId == KEY_TWO) {
            return KEY_ONE;
        }

        revert InvalidKey();
    }
}
