// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "contracts/BanklessWallet.sol";

contract BanklessStorage {

    mapping (address => bool) wallets;
    mapping (address => mapping(address => bool)) public userWallets;
    mapping (address => mapping(address => bool)) public guardianWallets;

    modifier onlyBanklessWallet {
        require(wallets[msg.sender], "Only a Bankless Wallet can call this function");
        _;
    }

    event WalletAdded(address walletAddress);

    event OwnerAdded(address owner, address walletAddress);

    event GuardiansAdded(address[] guardians, address walletAddress);

    event OwnerRemoved(address oldOwner, address newOwner);

    event GuardianTransferred(address newGuardian, address oldGuardian);

    event GuardianAdded(address newGuardian);

    event GuardianRemoved(address guardian);

    function setWalletAddress (address _owner, address _walletAddress) internal  {
        BanklessWallet wallet = BanklessWallet(_walletAddress);
        require(wallet.owner() == _owner, "The given address is not the owner");

        userWallets[_owner][_walletAddress] = true;
        wallets[_walletAddress] = true;
        emit WalletAdded(_walletAddress);
        emit OwnerAdded(_owner, _walletAddress);
    }

    function setGuardianAddress (address[] memory guardians, address _walletAddress) internal {
        BanklessWallet wallet = BanklessWallet(_walletAddress);

        for (uint i = 0 ; i < guardians.length; i++) 
        {
            require(wallet.isGuardian(guardians[i]), "The given address is not a guardian");
            guardianWallets[guardians[i]][_walletAddress] = true;
        }

        emit GuardiansAdded(guardians, _walletAddress);
    }

    function removeOwner (address oldOwner, address proposedOwner, address guardian) onlyBanklessWallet external  {
        require(guardianWallets[guardian][msg.sender], "Guardian is not Authorized");
        require(userWallets[oldOwner][msg.sender], "Owner is not valid");

        userWallets[oldOwner][msg.sender] = false;
        userWallets[proposedOwner][msg.sender] = true;
        emit OwnerRemoved(oldOwner, proposedOwner);
    }

    function transferGuardian (address oldGuardian, address proposedGuardian, address owner) onlyBanklessWallet external  {
        require(userWallets[owner][msg.sender], "Owner is not Authorized");
        require(guardianWallets[oldGuardian][msg.sender], "Guardian is not Valid");

        guardianWallets[oldGuardian][msg.sender] = false;
        guardianWallets[proposedGuardian][msg.sender] = true;
        emit GuardianTransferred(proposedGuardian, oldGuardian);
    }

    function addGuardian (address proposedGuardian, address owner) onlyBanklessWallet external {
        require(userWallets[owner][msg.sender], "Owner is not Authorized");
        
        guardianWallets[proposedGuardian][msg.sender] = true;
        emit GuardianAdded(proposedGuardian);
    }

    function removeGuardian (address guardian, address owner) onlyBanklessWallet external {
        require(userWallets[owner][msg.sender], "Owner is not Authorized");

        guardianWallets[guardian][msg.sender] = false;
        emit GuardianRemoved(guardian);
    }
}