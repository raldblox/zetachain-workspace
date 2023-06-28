/**
 *
 * @title NAMESPACE TOKEN
 * @author raldblox.eth
 *
 */

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.2 <0.9.0;

import "./NamespaceRegistrar.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@zetachain/protocol-contracts/contracts/evm/interfaces/ZetaInterfaces.sol";
import "@zetachain/protocol-contracts/contracts/evm/tools/ZetaInteractor.sol";

interface CrossChainNamespaceErrors {
    error InvalidMessageType();
    error InvalidTransferCaller();
    error ErrorApprovingZeta();
}

contract CrossChainNamespace is
    ERC721("CrossChain Namespace", "CNS"),
    Ownable2Step,
    ZetaInteractor,
    ZetaReceiver,
    CrossChainNamespaceErrors
{
    using Counters for Counters.Counter;
    using Strings for uint256;
    address private admin;
    string public chain;

    NamespaceRegistrar public registrar;

    bytes32 public constant CROSS_CHAIN_TRANSFER_MESSAGE =
        keccak256("CROSS_CHAIN_TRANSFER");

    IERC20 internal immutable _zetaToken;

    string public baseURI;

    Counters.Counter public tokenIds;

    ZetaTokenConsumer private immutable _zetaConsumer;

    string private contractUri =
        '{"name":"namespace","description":"Connect, create, and control with Namespace."}';

    event NewToken(
        uint256 indexed tokenId,
        address indexed owner,
        string tokenType
    );

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not an admin");
        _;
    }

    mapping(string => uint256) public nameIds;
    mapping(uint256 => bool) isNames;
    mapping(uint256 => string) public names;
    mapping(uint256 => string) public spaces;
    mapping(uint256 => string) colors;
    mapping(uint256 => string) bgs;

    constructor(
        address connectorAddress,
        address zetaTokenAddress,
        address zetaConsumerAddress,
        bool useEven,
        string memory chainName
    ) ZetaInteractor(connectorAddress) {
        _zetaToken = IERC20(zetaTokenAddress);
        _zetaConsumer = ZetaTokenConsumer(zetaConsumerAddress);

        registrar = new NamespaceRegistrar(msg.sender);
        chain = chainName;

        /**
         * @dev A simple way to prevent collisions between cross-chain token ids
         * As you can see below, the mint function should increase the counter by two
         */
        tokenIds.increment();
        if (useEven) tokenIds.increment();
    }

    function setContractUri(string memory _new) external onlyAdmin {
        contractUri = _new;
    }

    function isAdmin() internal view returns (bool) {
        return admin == msg.sender;
    }

    function setColor(
        uint256 tokenId,
        string memory color,
        string memory bg
    ) external onlyAdmin {
        if (!isAdmin()) {
            require(ownerOf(tokenId) == msg.sender);
        }
        colors[tokenId] = color;
        bgs[tokenId] = bg;
    }

    function mint(
        string memory _name,
        address _owner,
        bool isName
    ) public returns (uint256) {
        uint256 newNamespaceId = tokenIds.current();

        /**
         * @dev Always increment by two to keep ids even/odd (depending on the chain)
         * Check the constructor for further reference
         */
        tokenIds.increment();
        tokenIds.increment();

        _safeMint(_owner, newNamespaceId);

        isNames[newNamespaceId] = isName;
        if (isName) {
            names[newNamespaceId] = _name;
        } else {
            spaces[newNamespaceId] = _name;
        }

        emit NewToken(newNamespaceId, _owner, isName ? "Name" : "Space");
        return tokenIds.current();
    }

    function contractURI() external view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(abi.encodePacked(contractUri)))
                )
            );
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Nonexistent Token");

        string memory name_ = "";
        string memory image_ = "";
        string memory attribute_ = "";
        string memory visualizer_ = "";
        string memory description_ = "";

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name_,
                                '", "description":"',
                                description_,
                                '", "image": "',
                                image_,
                                '", "attributes": ',
                                "[",
                                attribute_,
                                "]",
                                ', "animation_url": "',
                                visualizer_,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    function generateImage(
        uint256 tokenId
    ) public view returns (string memory) {
        string memory encodedBytes = Base64.encode(
            bytes(
                abi.encodePacked(
                    '<svg viewBox="0 0 500 500" xmlns="http://www.w3.org/2000/svg">',
                    "<style>svg {background-color:",
                    "#94ff2b",
                    ";} text {fill:",
                    "#131313",
                    ";font-weight: bold; font-family: sans-serif;}</style>",
                    '<text x="480" y="50" font-size="30" text-anchor="end" font-weight="bold">(',
                    Strings.toString(tokenId),
                    ')</text><text x="20" y="50" font-size="30" font-weight="bold">',
                    chain,
                    "</text></svg>"
                )
            )
        );

        return
            string(
                abi.encodePacked("data:image/svg+xml;base64,", encodedBytes)
            );
    }

    function recover() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool recovered, ) = admin.call{value: amount}("");
        require(recovered, "Failed to recover.");
    }

    /**
     * @dev Useful for cross-chain minting
     */
    function _mintId(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId);
    }

    function _burnNamespace(uint256 burnedNamespaceId) internal {
        _burn(burnedNamespaceId);
    }

    /**
     * @dev Cross-chain functions
     */

    function crossChainTransfer(
        uint256 crossChainId,
        address to,
        uint256 tokenId,
        string memory name,
        bool isName
    ) external payable {
        if (!_isValidChainId(crossChainId)) revert InvalidDestinationChainId();
        if (!_isApprovedOrOwner(_msgSender(), tokenId))
            revert InvalidTransferCaller();

        uint256 crossChainGas = 18 * (10 ** 18);
        uint256 zetaValueAndGas = _zetaConsumer.getZetaFromEth{
            value: msg.value
        }(address(this), crossChainGas);
        _zetaToken.approve(address(connector), zetaValueAndGas);

        _burnNamespace(tokenId);

        connector.send(
            ZetaInterfaces.SendInput({
                destinationChainId: crossChainId,
                destinationAddress: interactorsByChainId[crossChainId],
                destinationGasLimit: 500000,
                message: abi.encode(
                    CROSS_CHAIN_TRANSFER_MESSAGE,
                    tokenId,
                    msg.sender,
                    to,
                    name,
                    isName
                ),
                zetaValueAndGas: zetaValueAndGas,
                zetaParams: abi.encode("")
            })
        );
    }

    function onZetaMessage(
        ZetaInterfaces.ZetaMessage calldata zetaMessage
    ) external override isValidMessageCall(zetaMessage) {
        (
            bytes32 messageType,
            uint256 tokenId,
            ,
            /**
             * @dev this extra comma corresponds to address from
             */
            address to,
            string memory name,
            bool isName
        ) = abi.decode(
                zetaMessage.message,
                (bytes32, uint256, address, address, string, bool)
            );

        if (messageType != CROSS_CHAIN_TRANSFER_MESSAGE)
            revert InvalidMessageType();

        _mintId(to, tokenId);

        isNames[tokenId] = isName;

        if (isName) {
            names[tokenId] = name;
        } else {
            spaces[tokenId] = name;
        }
    }

    function onZetaRevert(
        ZetaInterfaces.ZetaRevert calldata zetaRevert
    ) external override isValidRevertCall(zetaRevert) {
        (
            bytes32 messageType,
            uint256 tokenId,
            address from,
            string memory name,
            bool isName
        ) = abi.decode(
                zetaRevert.message,
                (bytes32, uint256, address, string, bool)
            );

        if (messageType != CROSS_CHAIN_TRANSFER_MESSAGE)
            revert InvalidMessageType();

        _mintId(from, tokenId);

        isNames[tokenId] = isName;

        if (isName) {
            names[tokenId] = name;
        } else {
            spaces[tokenId] = name;
        }
    }
}
