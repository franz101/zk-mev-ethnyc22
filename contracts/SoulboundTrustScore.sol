import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";


const BITDAO_ADDRESS = "0x1A4b46696b2bB4794Eb3D4c26f1c55F9170fa4C5";
const LENS_ADDRES  = "0xdb46d1dc155634fbc732f92e853b10b288ad5a1d";
const WORLD_COIN_ADDRESS  = "0xdb46d1dc155634fbc732f92e853b10b288ad5a1d";

contract SoulBoundTrustScore is ERC165 {
    using Address for address;
    using Strings for uint256;

    mapping(uint256 => address) private _owners;
    mapping(uint256 => uint256) private _trustScore;
    mapping(uint256 => uint256) private _worldCoinOwner;
    address private _trustOracle;
    // Token name
    string private _name;
    // Token symbol
    string private _symbol;

    constructor(
        address trustOracle,
        string memory name_,
        string memory symbol_
    ) {
        _trustOracle = trustOracle;
        _name = name_;
        _symbol = symbol_;
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

    function rescue(uint256 worldCoinId) public {
        uint256 ownerId = _worldCoinOwner[worldCoinId];
        _owners[ownerId] = msg.sender;
    }

    function getScore(uint256 ownerId) public view returns (uint256) {
        return _trustScore[ownerId];
    }

    function addWorldCoinScore(uint256 ownerId) public returns (uint256) {
        _trustScore[ownerId] += 5;
        _trustScore[ownerId] += 5;
        return _trustScore[ownerId];
    }
    function bitDao(uint256 ownerId) public returns (uint256) {
        _trustScore[ownerId] += 5;
        _trustScore[ownerId] += 5;
        return _trustScore[ownerId];
    }

    function addLensScore(uint256 ownerId) public returns (uint256) {
        //todo require
        LENS_ADDRES .defaultProfile(msg.sender)
        _trustScore[ownerId] += 5;
        return _trustScore[ownerId];
    }

    function addOracleScore(uint256 ownerId, uint256 score)
        public
        returns (uint256)
    {
        //todo require
        _trustScore[ownerId] += score;
        return _trustScore[ownerId];
    }
}
