// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ERC20ReturnFalseMock } from "@openzeppelin/contracts/mocks/token/ERC20ReturnFalseMock.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MockTokenTransferFailed is ERC20 {
    constructor() ERC20("FalseToken", "FALSE") {}

    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }

    function mint(address to, uint256 amount) external returns (bool) {
        _mint(to, amount);
        return true;
    }
}

// ERC20ReturnFalseMock 的两个 transfer 都return false，有时不太灵活，会造成麻烦
contract MockTokenTransferFromFailed is ERC20ReturnFalseMock {
    constructor() ERC20("FalseToken", "FALSE") {}

    function mint(address to, uint256 amount) external returns (bool) {
        _mint(to, amount);
        return true;
    }
}

contract MockTokenMintFailed is ERC20Burnable {
    constructor() ERC20("FalseToken", "FALSE") {}

    function mint(address _to, uint256 _amount) external returns (bool) {
        return false;
    }
}
