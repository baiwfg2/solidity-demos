//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MyNFT} from "./MyNFT.sol";

contract WrappedNFT is MyNFT {
    constructor(string memory tokenName, string memory tokenSymbol) 
        MyNFT(tokenName, tokenSymbol) {}

    function mintWithSpecificTokenId(address to, uint256 _tokenId) public {
        _safeMint(to, _tokenId);
    }
}