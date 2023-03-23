// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface MyNFT  {
    function createFromERC20(address sender) external returns (uint256);
    function multiCreateFromERC20(address sender, uint256 count) external returns (uint256[] memory);
}