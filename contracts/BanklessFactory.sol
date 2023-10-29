// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "contracts/BanklessWallet.sol";
import "contracts/BanklessStorage.sol";

contract BanklessFactory is BanklessStorage{

    event BanklessWalletDeployed(address indexed addr, uint256 salt);

    function getBytecode(address owner, address[] memory guardianAddr, uint256 threshold) public pure returns(bytes memory) {
        bytes memory bytecode = type(BanklessWallet).creationCode;
        return abi.encodePacked(bytecode, abi.encode(owner, guardianAddr, threshold));
    }

    function getWalletAddress(bytes memory bytecode, uint _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            _salt,
            keccak256(bytecode)
        ));

        return address(uint160(uint256(hash)));
    }

    function deployBanklessWallet( address[] memory guardianAddr, uint256 threshold, uint _salt) public payable{
        address addr;

        bytes memory bytecode = getBytecode(msg.sender, guardianAddr, threshold);

        assembly {
            addr := create2(
                callvalue(),
                add(bytecode, 0x20),
                mload(bytecode),
                _salt
            )
        

            if iszero(extcodesize(addr)) {
                revert(0,0)
            }
        }

        BanklessStorage.setWalletAddress(msg.sender, addr);
        BanklessStorage.setGuardianAddress(guardianAddr, addr);
        emit BanklessWalletDeployed(addr, _salt);
    }

}