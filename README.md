# Safe Module Task

Relevant files are in `/src` and `/test`.

# Running

I did have to make some changes to the safe-contracts submodule to get the token to deploy with the correct compiler version. This should probably be done upstream anyway.

In `/lib/safe-contracts/package.json`, change the version of `@openzeppelin-contracts` to `^4.0.0`.

Then in `lib/safe-contracts/contracts/test/ERC20Token.sol`, change the pragma solidity version to `^0.8.0`.

I also had to change the import from `@openzeppelin/...` to `node_modules/@openzeppelin/...` for some reason...

Obviously I would fix this if it were for something real, but I figured that you just want to look at the module implementation and tests, and any silly environment hacks to get it working would be kindly overlooked :)

Make sure that you have foundry, and then:

```
forge test
```