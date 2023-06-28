/**
 *
 * @title NAMESPACE
 * @author raldblox.eth
 *
 */

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

import "./NamespaceToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NamespaceRegistrar {
    using SafeMath for uint256;
    address admin;
    uint256 public nameFee;
    uint256 public spaceFee;
    uint256 public connectFee;
    address public token;

    struct Name {
        string[] names;
        mapping(string => address) creator;
        mapping(string => uint256) tokenIds;
        mapping(string => string[]) spaces;
        mapping(address => mapping(string => string[])) links; // @note map address to name.space to links
        mapping(string => mapping(string => address)) wallets; // @note map address to name.space to address
    }

    struct Space {
        string[] spaces;
        mapping(string => bool) isPrivate;
        mapping(string => address) creator;
        mapping(string => string) orgnames;
        mapping(string => string) orglogos;
        mapping(string => string) orgsites;
        mapping(string => uint256) tokenIds;
        mapping(string => string) description;
        mapping(string => string[]) names;
        mapping(string => string[]) links;
        mapping(string => uint256) membershipFees;
        mapping(string => mapping(address => bool)) isAllowed; // @note allowed addresses for private spaces
    }

    Name private name;
    Space private space;

    mapping(address => string) primaryNames;
    mapping(string => bool) isNames;

    constructor(address _admin) {
        admin = _admin;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not an admin");
        _;
    }

    modifier onlyNameOwner(string memory _name) {
        require(
            ERC721(token).ownerOf(name.tokenIds[_name]) == msg.sender,
            "Not Authorized"
        );
        _;
    }

    function isAdmin() internal view returns (bool) {
        return admin == msg.sender;
    }

    function setWallets(
        string memory _name,
        string memory _space,
        address _wallet
    ) external onlyNameOwner(_name) {
        require(_wallet != address(0), "Wallet cannot be zero");
        name.wallets[_name][_space] = _wallet;
    }

    function recover() external onlyAdmin {
        uint256 amount = address(this).balance;
        (bool recovered, ) = admin.call{value: amount}("");
        require(recovered, "Failed to recover.");
    }
}
