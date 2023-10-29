// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.20;

import "contracts/BanklessWallet.sol";

contract BanklessFactory {

    event WalletDeployed(address indexed addr, uint256 salt);

    function getBytecode(address owner, address[] memory guardianAddr, uint256 threshold) public pure returns(bytes memory) {
        bytes memory bytecode = type(BanklessWallet).creationCode;
        return abi.encodePacked(bytecode, abi.encode(owner, guardianAddr, threshold));
    }

    function getAddress(bytes memory bytecode, uint _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            _salt,
            keccak256(bytecode)
        ));

        return address(uint160(uint256(hash)));
    }

    function deploy(bytes memory bytecode, uint _salt) public payable{
        address addr;

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

        emit WalletDeployed(addr, _salt);
    }

}