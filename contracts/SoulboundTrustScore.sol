// SPDX-License-Identifier: MIT

//import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IERC20 {
    function balanceOf(address _owner) external view returns (uint256 balance);
}

interface ILensHub {
    function defaultProfile(address wallet) external view returns (uint256);
}

bytes4 constant InterfaceId_ERC165 = 0x01ffc9a7;

contract SoulBoundTrustScore is Ownable, ERC165 {
    using Address for address;
    using Strings for uint256;
    address immutable BITDAO_ADDRESS;
    address immutable LENS_ADDRES;

    address immutable WORLD_COIN_ADDRESS;
    bytes4 worldCoinSelector;

    address public _trustOracle;
    bytes4 trustOracleSelector;

    mapping(uint256 => address) private _owners;
    mapping(uint256 => uint256) private _trustScore;
    mapping(uint256 => uint256) private _worldCoinOwner;

    mapping(uint256 => mapping(bytes4 => bool)) _passedChecks;
    // lens_test: 10
    //

    // Token name
    string private _name;
    // Token symbol
    string private _symbol;

    constructor(
        address BITDAO_ADDRESS_,
        address LENS_ADDRES_,
        string memory name_,
        string memory symbol_,
        address worldCoinAdrs,
        address trustOracle_
    ) {
        BITDAO_ADDRESS = BITDAO_ADDRESS_;
        LENS_ADDRES = LENS_ADDRES_;
        _trustOracle = trustOracle_;
        _name = name_;
        _symbol = symbol_;
        _registerInterface(InterfaceId_ERC165);
        WORLD_COIN_ADDRESS = worldCoinAdrs;
        _trustOracle = trustOracle_;
    }

    // allow test run only if owner did not receive score for it yet
    modifier oneTimeScore(uint256 ownerId, bytes4 testType) {
        if (!_passedChecks[ownerId][testType]) {
            _;
        }
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        address owner = _owners[tokenId];
        require(
            owner != address(0),
            "Trust score: owner query for nonexistent token"
        );
        return owner;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external {}

    function rescue(uint256 worldCoinId) public {
        uint256 ownerId = _worldCoinOwner[worldCoinId];
        _owners[ownerId] = msg.sender;
    }

    function getScore(uint256 ownerId) public view returns (uint256) {
        return _trustScore[ownerId];
    }

    function setWorldCoinSelector(bytes4 worldcoinSelector) external onlyOwner {
        worldCoinSelector = worldcoinSelector;
    }

    function addWorldCoinScore(uint256 ownerId)
        public
        oneTimeScore(ownerId, this.addWorldCoinScore.selector)
    {
        bytes memory data = abi.encodeWithSelector(worldCoinSelector, ownerId);
        (bool success, bytes memory res) = WORLD_COIN_ADDRESS.call(data);
        if (res.length > 0) {
            _trustScore[ownerId] += 5;
            _trustScore[ownerId] += 5;
            _passedChecks[ownerId][this.addWorldCoinScore.selector] = true;
        }
    }

    function addBitDaoScore(uint256 ownerId)
        public
        oneTimeScore(ownerId, this.addBitDaoScore.selector)
    {
        if (IERC20(BITDAO_ADDRESS).balanceOf(_owners[ownerId]) > 0) {
            _trustScore[ownerId] += 5;
            _trustScore[ownerId] += 5;
            _passedChecks[ownerId][this.addBitDaoScore.selector] = true;
        }
    }

    function addLensScore(uint256 ownerId)
        public
        oneTimeScore(ownerId, this.addLensScore.selector)
    {
        if (ILensHub(LENS_ADDRES).defaultProfile(msg.sender) > 0) {
            _trustScore[ownerId] += 5;
            _passedChecks[ownerId][this.addLensScore.selector] = true;
        }
    }

    function changeTrustedOracle(address newTrustedOracle) external onlyOwner {
        _trustOracle = newTrustedOracle;
    }

    function setTrustedOracleSelector(bytes4 trustOracleSelector_)
        external
        onlyOwner
    {
        trustOracleSelector = trustOracleSelector_;
    }

    function addOracleScore(uint256 ownerId)
        public
        oneTimeScore(ownerId, this.addOracleScore.selector)
    {
        bytes memory data = abi.encodeWithSelector(
            trustOracleSelector,
            ownerId
        );
        (bool success, bytes memory res) = _trustOracle.call(data);
        if (res.length > 0) {
            _trustScore[ownerId] += 5;
            _passedChecks[ownerId][this.addOracleScore.selector] = true;
        }
    }

    /// @dev Whether a nullifier hash has been used already. Used to prevent double-signaling
    mapping(uint256 => bool) internal nullifierHashes;

    mapping(bytes4 => bool) internal supportedInterfaces;

    function _registerInterface(bytes4 _interfaceId) internal {
        require(_interfaceId != 0xffffffff);
        supportedInterfaces[_interfaceId] = true;
    }

    function supportsInterface(bytes4 interfaceID)
        public
        view
        override
        returns (bool)
    {
        return supportedInterfaces[interfaceID];
    }

    error InvalidNullifier();
}
