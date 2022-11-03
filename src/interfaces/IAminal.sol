pragma solidity ^0.8.16;

import "openzeppelin/token/ERC721/IERC721.sol";

interface IAminal is IERC721 {
    error AminalDoesNotExist();
    error SenderDoesNotHaveMaxAffinity();
    error ExceedsMaxLocation();
    error OnlyMoveWithGoTo();
    error MaxAminalsSpawned();
    error OnlyEquipOwnedAccessory();

    event AminalSpawned(
        address spawner,
        uint256 aminalId,
        uint256 value,
        uint256 affinity
    );

    event AminalFed(
        address feeder,
        uint256 aminalId,
        uint256 value,
        uint256 newAffinity,
        bool newMax
    );

    function locationOf(uint256 aminalId)
        external
        view
        returns (uint160 location);

    function addressOf(uint256 aminalId)
        external
        view
        returns (address aminalAddress);

    function spawn() external payable;

    function feed(uint256 aminalId) external payable;

    function goTo(uint256 aminalId, uint160 location) external;

    function affinity(uint256, address) external view returns (uint256);

    function maxAffinity(uint256) external view returns (uint256);
    
    function equip(uint256 aminalId, address accessory, uint256 accessoryId) external;

    function unequip(uint256 aminalId, address accessory, uint256 accessoryId) external;
}
