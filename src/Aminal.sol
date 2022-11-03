// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "openzeppelin/token/ERC721/ERC721.sol";
import "@core/interfaces/IAminal.sol";
import "@core/interfaces/IAccessories.sol";
import "@core/interfaces/IAminalCoordinates.sol";

contract Aminal is ERC721, IAminal {

    uint256 constant MAX_AMINALS = 1e4;

    uint256 currentAminalId;

    bool private going;
    
    IAminalCoordinates public coordinates;

    modifier goingTo() {
        going = true;
        _;
        going = false;
    }

    struct Accessory {
        address accessoryContract;
        uint256 accessoryId;
        bool equipped;
    }

    mapping(uint256 => mapping(address => uint256)) public affinity;
    mapping(uint256 => uint256) public maxAffinity;

    mapping(uint256 => mapping(address => Accessory)) public accessories;

    constructor(address _coordinatesMap) ERC721("Aminal", "AMNL") {
        coordinates = IAminalCoordinates(_coordinatesMap);
    }


    function addressOf(uint256 aminalId)
        public
        view
        returns (address aminalAddress)
    {
        aminalAddress = address(
            uint160(
                uint256(keccak256(abi.encodePacked(address(this), aminalId)))
            )
        );
    }

    function exists(uint256 aminalId) public view returns (bool) {
        return _exists(aminalId);
    }

    function spawn() public payable {
        // TODO require nonzero value?
        if (currentAminalId == MAX_AMINALS) revert MaxAminalsSpawned();
        currentAminalId++;
        uint256 senderAffinity = updateAffinity(
            currentAminalId,
            msg.sender,
            msg.value
        );

        uint256 pseudorandomness = uint256(
            keccak256(
                abi.encodePacked(blockhash(block.number - 1), currentAminalId)
            )
        );
        address location = address(uint160(pseudorandomness % coordinates.maxLocation()));
        _mint(location, currentAminalId);

        emit AminalSpawned(
            msg.sender,
            currentAminalId,
            msg.value,
            senderAffinity
        );
    }

    function feed(uint256 aminalId) public payable {
        uint256 senderAffinity = updateAffinity(
            aminalId,
            msg.sender,
            msg.value
        );

        bool newMax;
        if (senderAffinity > maxAffinity[aminalId]) {
            maxAffinity[aminalId] = senderAffinity;
            newMax = true;
        }

        emit AminalFed(msg.sender, aminalId, msg.value, senderAffinity, newMax);
    }

    function goTo(uint256 aminalId, uint160 location) public goingTo {
        if (!_exists(aminalId)) revert AminalDoesNotExist();
        if (affinity[aminalId][msg.sender] != maxAffinity[aminalId])
            revert SenderDoesNotHaveMaxAffinity();
        if (location > coordinates.maxLocation()) revert ExceedsMaxLocation();

        _transfer(ownerOf(aminalId), address(location), aminalId);
    }

    function equip(
        uint256 aminalId,
        address accessory,
        uint256 accessoryId
    ) external {
        if (!_exists(aminalId)) revert AminalDoesNotExist();
        if (affinity[aminalId][msg.sender] != maxAffinity[aminalId])
            revert SenderDoesNotHaveMaxAffinity();
        if (IAccessories(accessory).ownerOf(accessoryId) != addressOf(aminalId))
            revert OnlyEquipOwnedAccessory();

        accessories[aminalId][accessory] = Accessory(
            accessory,
            accessoryId,
            true
        );
    }

    function unequip(
        uint256 aminalId,
        address accessory,
        uint256 accessoryId
    ) external {
        if (!_exists(aminalId)) revert AminalDoesNotExist();
        if (affinity[aminalId][msg.sender] != maxAffinity[aminalId])
            revert SenderDoesNotHaveMaxAffinity();
        if (IAccessories(accessory).ownerOf(accessoryId) != addressOf(aminalId))
            revert OnlyEquipOwnedAccessory();

        accessories[aminalId][accessory] = Accessory(
            accessory,
            accessoryId,
            false
        );
    }

    function updateAffinity(
        uint256 aminalId,
        address sender,
        uint256 value
    ) internal returns (uint256 senderAffinity) {
        // TODO how should affinity accumulate?
        affinity[aminalId][sender] += value;
        senderAffinity = affinity[aminalId][sender];
    }

    // Protect against someone mining the location key by disallowing any tranfser besides goto
    function _beforeTokenTransfer(
        address,
        address,
        uint256
    ) internal view {
        if (!going) revert OnlyMoveWithGoTo();
    }
}
