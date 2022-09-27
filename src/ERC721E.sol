// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./interfaces/IERC721E.sol";
import "./interfaces/IERC721.sol";
import "./utils/Base64.sol";
import "./utils/Strings.sol";

////////////////////////////////////////////////////////////////////////
//                                                                    //
//    ███████╗██████╗  ██████╗    ███████╗██████╗  ██╗    ███████╗    //
//    ██╔════╝██╔══██╗██╔════╝    ╚════██║╚════██╗███║    ██╔════╝    //
//    █████╗  ██████╔╝██║             ██╔╝ █████╔╝╚██║    █████╗      //
//    ██╔══╝  ██╔══██╗██║            ██╔╝ ██╔═══╝  ██║    ██╔══╝      //
//    ███████╗██║  ██║╚██████╗       ██║  ███████╗ ██║    ███████╗    //
//    ╚══════╝╚═╝  ╚═╝ ╚═════╝       ╚═╝  ╚══════╝ ╚═╝    ╚══════╝    //
//                                                                    //
////////////////////////////////////////////////////////////////////////

/// @notice An ERC-721 implementation with an NFT linked with every wallet by default
/// @author k0rean_rand0m (https://twitter.com/k0rean_rand0m | https://github.com/k0rean-rand0m)
abstract contract ERC721E is IERC721E, IERC721  {

    using Strings for uint256;

    //// STORAGE ////

    // PUBLIC //
    string public name;
    string public symbol;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    // PRIVATE //

    mapping(uint256 => address) private _ownerOf;
    mapping(address => uint256) private _balanceOf;
    mapping(uint256 => bool) private _minted;
    bool private _transferable;

    //// CONSTRUCTOR ////

    constructor(string memory _name, string memory _symbol, bool transferable) {
        name = _name;
        symbol = _symbol;
        _transferable = transferable;
    }

    //// IERC721E IMPLEMENTATION ////

    function originalTokenOf(address originalOwner) public pure virtual returns (uint256 id) {
        return uint256(bytes32(bytes20(originalOwner)) >> 96);
    }

    function originalOwnerOf(uint256 id) public pure virtual returns (address originalOwner) {
        require(abi.encodePacked(id).length <= 20, "NOT_EXISTS");
        return address(bytes20(bytes32(id) << 96));
    }

    //// IERC721 IMPLEMENTATION ////

    function tokenURI(uint256 id) public view virtual returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
        '{',
            '"name": "ERC721E #', id.toString(), '",',
            '"external_url": "https://twitter.com/k0rean_rand0m"',
            '"description": "A token you already own",',
            '"animation_url": "https://erc721wb.github.io?collection=wallet_number&id=', id.toString(), '"'
        '}'
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(dataURI)
            )
        );
    }

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        require(abi.encodePacked(id).length <= 20, "NOT_EXISTS");

        owner = _ownerOf[id];
        if (owner == address(0) && !_minted[id]) {
            return originalOwnerOf(id);
        }
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "ZERO_ADDRESS");

        uint256 balance = _balanceOf[owner];
        if (!_minted[originalTokenOf(owner)]) {
            balance += 1;
        }
        return balance;
    }

    function approve(address spender, uint256 id) public virtual {
        address owner = ownerOf(id);
        require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");

        getApproved[id] = spender;
        emit Approval(owner, spender, id);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        require(from == ownerOf(id), "WRONG_FROM");
        require(to != address(0), "INVALID_RECIPIENT");
        require(
            msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            "NOT_AUTHORIZED"
        );

        if (!_minted[id]) {
            _mint(originalOwnerOf(id), id);
        }

        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;
        delete getApproved[id];
        emit Transfer(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public virtual {
        transferFrom(from, to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, from, id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return
            interfaceId == type(IERC721E).interfaceId ||
            interfaceId == 0x01ffc9a7 || // ERC165 Interface ID for ERC165
            interfaceId == 0x80ac58cd || // ERC165 Interface ID for ERC721
            interfaceId == 0x5b5e139f; // ERC165 Interface ID for ERC721Metadata;
    }

    //// INTERNALS ////

    function _mint(address to, uint256 id) internal virtual {
        require(to != address(0), "INVALID_RECIPIENT");
        require(_ownerOf[id] == address(0), "ALREADY_MINTED");

        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[id] = to;
        _minted[id] = true;
        emit Transfer(address(0), to, id);
    }

    function _burn(uint256 id) internal virtual {
        address owner = _ownerOf[id];
        require(owner != address(0), "NOT_MINTED");

        unchecked {
            _balanceOf[owner]--;
        }

        delete _ownerOf[id];
        delete getApproved[id];
        emit Transfer(owner, address(0), id);
    }

    function _safeMint(address to, uint256 id) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }

    function _safeMint(
        address to,
        uint256 id,
        bytes memory data
    ) internal virtual {
        _mint(to, id);

        require(
            to.code.length == 0 ||
                ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, data) ==
                ERC721TokenReceiver.onERC721Received.selector,
            "UNSAFE_RECIPIENT"
        );
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}