// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol";

contract BanklessWallet is ReentrancyGuard {

    address public owner;

    uint256 public threshold;

    mapping(address => bool) public isGuardian;

    bool public inRecovery;

    bool public inGuardianRequest;

    uint256 public currRecoveryRound;

    struct RecoveryRequest {
        address proposedOwner;
        uint256 recoveryRound;
        bool isUsed;
    }

    mapping(address => RecoveryRequest) public guardianRecoveryRequest;

    struct GuardianRequest {
        address proposedGuardian;
        address guardianToChange;
        bool isUsed;
    }

    mapping(address => GuardianRequest) public guardianChangeRequest;

    modifier onlyOwner {
        require(msg.sender == owner, "Not Authorized");
        _;
    }

    modifier  onlyGuardian {
        require(isGuardian[msg.sender], "Only Guardian has access to this request");
        _;
    }

    modifier notInRecovery {
        require(!inRecovery, "Wallet is in Recovery mode");
        _;
    }

    modifier onlyInRecovery {
        require(inRecovery, "Wallet is not in Recovery mode");
        _;
    }

    modifier  notInGuardianRequest {
        require(!inGuardianRequest, "Existing Guardian Change Request found");
        _;
    }

    modifier  onlyInGuardianRequest {
        require(inGuardianRequest, "No Current Guardian Request found");
        _;
    }

    constructor(address _owner, address[] memory guardianAddr, uint256 _threshold){
        require(_threshold <= guardianAddr.length, "Threshold is too high");

         for(uint i = 0; i < guardianAddr.length; i++) {
            require(!isGuardian[guardianAddr[i]], "Duplicate Guardian Found");
            isGuardian[guardianAddr[i]] = true;
        }
        
        threshold = _threshold;
        owner = _owner;
    }

    event TransactionExecuted(address indexed callee, uint256 value, bytes data);
    
    event Transferred(address indexed destination, uint256 value);

    event RecoveryInitiated(address indexed by, address newProposedOwner, uint256 indexed round);

    event RecoverySupported(address indexed by, address newProposedOwner, uint256 indexed round);
    
    event RecoveryCancelled(address by, uint256 indexed round);

    event RecoveryExecuted(address oldOwner, address newOwner, uint256 indexed round);

    event GuardianshipTransferInitiated(address indexed newGuardian, address oldGuardian);

    event GuardianshipTransferExecuted(address indexed newGuardian, address oldGuardian);

    event GuardianshipTransferCancelled(address by);

    event GuardianshipRemovalExecuted(address by);

    function transfer(address payable destination, uint256 amount) external onlyOwner {
        destination.transfer(amount);
        emit Transferred(destination, amount);
    }
    
    function executeTx(address callee, uint256 value, bytes memory data) external onlyOwner nonReentrant returns(bytes memory){
        (bool success, bytes memory result) = callee.call{value: value}(data);
        require(success, "Contract Call Reverted");
        emit TransactionExecuted(callee, value, data);
        return result;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function initiateRecovery(address _proposedOwner) onlyGuardian notInRecovery notInGuardianRequest external {
        currRecoveryRound ++;
        guardianRecoveryRequest[msg.sender] = RecoveryRequest(
            _proposedOwner,
            currRecoveryRound,
            false
        );
        inRecovery = true;
        emit RecoveryInitiated(msg.sender, _proposedOwner, currRecoveryRound);
    }

    function supportRecovery(address _proposedOwner) onlyGuardian onlyInRecovery notInGuardianRequest external {
        guardianRecoveryRequest[msg.sender] = RecoveryRequest(
            _proposedOwner,
            currRecoveryRound,
            false
        );
        emit RecoverySupported(msg.sender, _proposedOwner, currRecoveryRound);
    }

    function cancelRecovery() onlyOwner onlyInRecovery external {
        inRecovery = false;
        emit RecoveryCancelled(msg.sender, currRecoveryRound);
    }

    function executeRecovery(address newOwner, address[] calldata guardianList) onlyGuardian onlyInRecovery notInGuardianRequest external {
        require(guardianList.length >= threshold, "more guardians required to transfer ownership");
        for (uint i = 0; i < guardianList.length; i++) {
            
            RecoveryRequest memory request = guardianRecoveryRequest[guardianList[i]];

            require(request.recoveryRound == currRecoveryRound, "round mismatch");
            require(request.proposedOwner == newOwner, "disagreement on new owner");
            require(!request.isUsed, "duplicate guardian used in recovery");

            guardianRecoveryRequest[guardianList[i]].isUsed = true;
        }

        inRecovery = false;
        address _oldOwner = owner;
        owner = newOwner;
        emit RecoveryExecuted(_oldOwner, newOwner, currRecoveryRound);
    }

    function transferGuardianship(address guardianToChange, address newGuardianHash) onlyGuardian notInGuardianRequest notInRecovery external {
        guardianChangeRequest[msg.sender] = GuardianRequest(
            newGuardianHash,
            guardianToChange,
            false
        );
        inGuardianRequest = true;
        emit GuardianshipTransferInitiated(newGuardianHash, guardianToChange);
    }

    function executeGuardianshipTransfer(address appellant) onlyOwner onlyInGuardianRequest notInRecovery external {
        GuardianRequest memory request = guardianChangeRequest[appellant];
        require(!request.isUsed, "Guardian Request is already Used");

        isGuardian[request.proposedGuardian] = true;
        isGuardian[request.guardianToChange] = false;
        guardianChangeRequest[appellant].isUsed = true;
        inGuardianRequest = false;
        emit GuardianshipTransferExecuted(request.proposedGuardian, request.guardianToChange);
    }

    function cancelGuardianshipTransfer() onlyOwner onlyInGuardianRequest notInRecovery external {
        inGuardianRequest = false;
        emit GuardianshipTransferCancelled(msg.sender);
    }

    function executeGuardianRemoval(address guardianHash, uint256 _threshold) external onlyOwner {
        require(isGuardian[guardianHash], "not a guardian");

       isGuardian[guardianHash] = false;
       threshold = _threshold;
       emit GuardianshipRemovalExecuted(msg.sender);
    }
} 