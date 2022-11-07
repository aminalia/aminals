// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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
        uint256 senderFed,
        uint256 affinity
    );

    event AminalFed(
        address feeder,
        uint256 aminalId,
        uint256 value,
        uint256 newAffinity,
        bool newMax
    );

    function exists(uint256 aminalId) external view returns (bool);

    function addressOf(uint256 aminalId)
        external
        view
        returns (address aminalAddress);

    function spawn() external payable;

    function feed(uint256 aminalId) external payable;

    function goTo(uint256 aminalId, uint160 location) external;

    function affinity(uint256, address) external view returns (uint256);

    function maxAffinity(uint256) external view returns (uint256);
}
