// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../lib/safe-contracts/contracts/GnosisSafe.sol";
import "../lib/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "../lib/safe-contracts/contracts/test/ERC20Token.sol";
import "../src/TokenDispensary.sol";

contract TokenDispensaryTest is Test {
    GnosisSafe masterCopy;
    GnosisSafe safe;
    GnosisSafeProxyFactory proxyFactory;
    GnosisSafeProxy proxy;
    TokenDispensary public tokenDispensary;

    address ADDRESS_0 = 0x0000000000000000000000000000000000000000;
    uint256 SAFE_OWNER_1_PRIVATE_KEY = 0x5af3;
    uint256 SAFE_OWNER_2_PRIVATE_KEY = 0x5afe5af3;
    uint256 FRAUDULENT_SAFE_OWNER_PRIVATE_KEY = 0xbad5af3;
    address ALLOWED_ACCOUNT = 0x000000000000000000000000000000000000baBe;
    uint256 ALLOWED_AMOUNT = 100e18;
    address FRAUDULENT_ACCOUNT = 0x0000000000000000000000000000000000000Bad;
    uint256 FRAUDULENT_AMOUNT = 101e18;

    address SAFE_OWNER_1;
    address SAFE_OWNER_2;

    ERC20Token testToken;

    address[] owners;

    function setUp() public {
        masterCopy = new GnosisSafe();
        proxy = new GnosisSafeProxy(address(masterCopy));
        safe = GnosisSafe(payable(address(proxy)));
        SAFE_OWNER_1 = vm.addr(SAFE_OWNER_1_PRIVATE_KEY);
        SAFE_OWNER_2 = vm.addr(SAFE_OWNER_2_PRIVATE_KEY);

        // Setup a "good" safe. Couldn't quite figure out what Solidity wanted
        // re. the datatypes so please excuse these ugly array ops.
        owners.push(SAFE_OWNER_1);
        owners.push(SAFE_OWNER_2);
        safe.setup(owners, 1, ADDRESS_0, "0x", ADDRESS_0, ADDRESS_0, 0, payable(ADDRESS_0));

        // Deploy a Token and send all of it to the Safe.
        testToken = new ERC20Token();
        testToken.transfer(address(safe), testToken.balanceOf(address(this)));

        // Deploy and setup the TokenDispensary module.
        tokenDispensary = new TokenDispensary();
        tokenDispensary.setup(address(safe), address(testToken));

        // Enable the TokenDispensary from the Safe.
        bytes memory safeAction = abi.encodeWithSelector(safe.enableModule.selector, address(tokenDispensary));
        bytes memory safeTransactionData = safe.encodeTransactionData(
            address(safe),
            0,
            safeAction,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            address(0),
            safe.nonce()
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SAFE_OWNER_1_PRIVATE_KEY, keccak256(safeTransactionData));
        // We have to change the order of (v, r, s) here because of the internal
        // signature parsing. See:
        // https://github.com/safe-global/safe-contracts/blob/main/contracts/common/SignatureDecoder.sol#L11
        bytes memory safeTransactionSignature = abi.encodePacked(r, s, v);
        // Execute the transaction on our Safe.
        safe.execTransaction(
            address(safe),
            0,
            safeAction,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            safeTransactionSignature
        );
    }

    // One big test of some of the withdraw scenarios. It's not exhaustive but
    // it's a demonstration of the types of things that I look for with tests.
    function testWithdraw() public {
        // Create the message for one of our safe's owners to sign:
        bytes32 validAllowanceHash = keccak256(
            abi.encodePacked(
                ALLOWED_ACCOUNT,
                ALLOWED_AMOUNT
            )
        );
        // Generate a valid signature and expect the transfer of tokens to be
        // successful, so measure the balances of the allowed user before and
        // after.
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                SAFE_OWNER_1_PRIVATE_KEY,
                validAllowanceHash
            );
            bytes memory validAllowanceSignature = abi.encodePacked(r, s, v);
            uint256 allowedAccountTokenBalanceBefore = testToken.balanceOf(ALLOWED_ACCOUNT);
            tokenDispensary.withdrawTokens(ALLOWED_ACCOUNT, ALLOWED_AMOUNT, validAllowanceSignature);
            uint256 allowedAccountTokenBalanceAfter = testToken.balanceOf(ALLOWED_ACCOUNT);
            assert(allowedAccountTokenBalanceAfter - allowedAccountTokenBalanceBefore == 100e18);
        }
        // Generate a valid signature from a different safe owner. Expect the
        // transfer of tokens to be successful, so measure the balances of the
        // allowed user before and after.
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                SAFE_OWNER_2_PRIVATE_KEY,
                validAllowanceHash
            );
            bytes memory validAllowanceSignature = abi.encodePacked(r, s, v);
            uint256 allowedAccountTokenBalanceBefore = testToken.balanceOf(ALLOWED_ACCOUNT);
            tokenDispensary.withdrawTokens(ALLOWED_ACCOUNT, ALLOWED_AMOUNT, validAllowanceSignature);
            uint256 allowedAccountTokenBalanceAfter = testToken.balanceOf(ALLOWED_ACCOUNT);
            assert(allowedAccountTokenBalanceAfter - allowedAccountTokenBalanceBefore == 100e18);
        }
        // Generate a fraudulent signature from a non-owner of the Safe. Expect
        // this transaction to revert.
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                FRAUDULENT_SAFE_OWNER_PRIVATE_KEY,
                validAllowanceHash
            );
            bytes memory invalidAllowanceSignature = abi.encodePacked(r, s, v);
            vm.expectRevert();
            tokenDispensary.withdrawTokens(ALLOWED_ACCOUNT, ALLOWED_AMOUNT, invalidAllowanceSignature);
        }
        // Generate a valid signature but pass in a fraudulent amount when
        // calling the module. Expect this transaction to revert.
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                SAFE_OWNER_1_PRIVATE_KEY,
                validAllowanceHash
            );
            bytes memory validAllowanceSignature = abi.encodePacked(r, s, v);
            vm.expectRevert();
            tokenDispensary.withdrawTokens(ALLOWED_ACCOUNT, FRAUDULENT_AMOUNT, validAllowanceSignature);
        }
        // Generate a valid signature but pass in a fraudulent account when
        // calling the module. Expect this transaction to revert.
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                SAFE_OWNER_1_PRIVATE_KEY,
                validAllowanceHash
            );
            bytes memory validAllowanceSignature = abi.encodePacked(r, s, v);
            vm.expectRevert();
            tokenDispensary.withdrawTokens(FRAUDULENT_ACCOUNT, ALLOWED_AMOUNT, validAllowanceSignature);
        }
    }
}
