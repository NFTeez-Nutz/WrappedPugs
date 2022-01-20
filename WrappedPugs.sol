// SPDX-License-Identifier: CC-BY-NC-2.5
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Based on WrappedPenguins 0x7822A2151Ad319040913D0EA4B93C64C0b49BF1B

contract WrappedPugs is
    ERC721,
    IERC721Receiver,
    Pausable,
    Ownable,
    ERC721Burnable
{
    event Wrapped(uint256 indexed tokenId);
    event Unwrapped(uint256 indexed tokenId);

    IERC721 immutable pugFrens;

    constructor(address pugFrensContractAddress_) ERC721("WrappedPugs", "WPS") {
        pugFrens = IERC721(pugFrensContractAddress_);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return string(abi.encodePacked(super.tokenURI(tokenId), ".json"));
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /// Wrap Pug Fren(s) to get Wrapped Pug(s)
    function wrap(uint256[] calldata tokenIds_) external {
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            pugFrens.safeTransferFrom(msg.sender, address(this), tokenIds_[i]);
        }
    }

    /// Unwrap to get Pug Fren(s) back
    function unwrap(uint256[] calldata tokenIds_) external {
        for (uint256 i = 0; i < tokenIds_.length; i++) {
            _safeTransfer(msg.sender, address(this), tokenIds_[i], "");
        }
    }

    function _flip(
        address who_,
        bool isWrapping_,
        uint256 tokenId_
    ) private {
        if (isWrapping_) {
            // Mint Wrapped Pug of same tokenID if not yet minted, otherwise swap for existing Wrapped Pug
            if (_exists(tokenId_) && ownerOf(tokenId_) == address(this)) {
                _safeTransfer(address(this), who_, tokenId_, "");
            } else {
                _safeMint(who_, tokenId_);
            }
            emit Wrapped(tokenId_);
        } else {
            pugFrens.safeTransferFrom(address(this), who_, tokenId_);
            emit Unwrapped(tokenId_);
        }
    }

    // Notice: You must use safeTransferFrom in order to properly wrap/unwrap your pug.
    function onERC721Received(
        address operator_,
        address from_,
        uint256 tokenId_,
        bytes memory data_
    ) external override returns (bytes4) {
        // Only supports callback from the original pugFrens contract and this contract
        require(
            msg.sender == address(pugFrens) || msg.sender == address(this),
            "must be PugFren or WrappedPugs"
        );

        bool isWrapping = msg.sender == address(pugFrens);
        _flip(from_, isWrapping, tokenId_);

        return this.onERC721Received.selector;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    fallback() external payable {}

    receive() external payable {}

    function withdrawETH() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function withdrawERC20(address token) external onlyOwner {
        bool success = IERC20(token).transfer(
            owner(),
            IERC20(token).balanceOf(address(this))
        );
        require(success, "Transfer failed");
    }

    // @notice Mints or transfers wrapped pug to owner for users who incorrectly transfer a Pug Fren or Wrapped Pug directly to the contract without using safeTransferFrom.
    // @dev This condition will occur if onERC721Received isn't called when transferring.
    function emergencyMintWrapped(uint256 tokenId_) external onlyOwner {
        if (pugFrens.ownerOf(tokenId_) == address(this)) {
            // Contract owns the Pug Fren.
            if (_exists(tokenId_) && ownerOf(tokenId_) == address(this)) {
                // Wrapped Pug is also trapped in contract.
                _safeTransfer(address(this), owner(), tokenId_, "");
                emit Wrapped(tokenId_);
            } else if (!_exists(tokenId_)) {
                // Wrapped Pug hasn't ever been minted.
                _safeMint(owner(), tokenId_);
                emit Wrapped(tokenId_);
            } else {
                revert("Wrapped Pug minted and distributed already");
            }
        } else {
            revert("Pug Fren is not locked in contract");
        }
    }
}
