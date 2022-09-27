// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./IERC165.sol";

/// @author k0rean_rand0m (https://twitter.com/k0rean_rand0m | https://github.com/k0rean-rand0m)

interface IERC721E is IERC165 {
    function transferable() external returns (bool);
    function originalTokenOf(address originalOwner) external view returns (uint256 id);
    function originalOwnerOf(uint256 id) external view returns (address originalOwner);
}