// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MandyNFT is ERC721URIStorage, Ownable {
    uint256 private _tokenIds;

    constructor(address initOwner) ERC721("MandyNFT", "MFT") Ownable(initOwner) {}

    function mintNFT(address recipient, string memory tokenUri) public onlyOwner returns(uint256) {
        _tokenIds++;
        uint256 newId = _tokenIds;
        _mint(recipient, newId);
        _setTokenURI(newId, tokenUri);
        return newId;
    }
}