// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "lib/safe-contracts/contracts/common/Enum.sol";
import "lib/safe-contracts/contracts/GnosisSafe.sol";

contract TokenDispensary {

  GnosisSafe public safe;
  address payable public token;

  /// @dev Setup for the module. Can only be called once.
  /// @param _safe The Safe we're operating on
  /// @param _token The token we're managing withdrawals for
  function setup(address _safe, address _token) public {
    require(_safe != address(0), "Module has already been setup");
    safe = GnosisSafe(payable(_safe));
    token = payable(_token);
  }

  /// @dev Withdraw tokens from the safe given a valid signature by _threshold of the safe's owners.
  /// @param to Destination address of token
  /// @param amt Token amount
  /// @param signatures Signatures from _threshold of the safe's owners
  function withdrawTokens (address to, uint256 amt, bytes calldata signatures) public {
    bytes memory allowanceData = abi.encodePacked(to, amt);
    // Create the relevant hash
    bytes32 validAllowanceHash = keccak256(allowanceData);
    // Verify the signatures - this will revert if signatures are not valid
    safe.checkSignatures(validAllowanceHash, allowanceData, signatures);
    // Then move the tokens out of the Safe
    bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", to, amt);
    safe.execTransactionFromModule(token, 0, data, Enum.Operation.Call);
  }
}

