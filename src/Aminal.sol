// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC721/ERC721.sol";
import "../lib/VRGDAs/src/LinearVRGDA.sol";

error AminalDoesNotExist();
error SenderDoesNotHaveMaxAffinity();
error ExceedsMaxLocation();
error OnlyMoveWithGoTo();
error MaxAminalsSpawned();

contract Aminal is ERC721 {
    constructor() ERC721("Aminal", "AMNL") {}

    uint160 constant MAX_LOCATION = 1e9;

    uint256 constant MAX_AMINALS = 1e4;

    uint256 currentAminalId;

    bool going;

    modifier goingTo() {
        going = true;
        _;
        going = false;
    }

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

    mapping(uint256 => mapping(address => uint256)) public affinity;
    mapping(uint256 => uint256) public maxAffinity;

    function locationOf(uint256 aminalId)
        public
        view
        returns (uint160 location)
    {
        if (!_exists(aminalId)) revert AminalDoesNotExist();
        return uint160(ownerOf(aminalId));
    }

    function addressOf(uint256 aminalId)
        public
        view
        returns (address aminalAddress)
    {
        aminalAddress = address(
            uint160(uint256(keccak256(abi.encodePacked(address(this), aminalId))))
        );
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
        address location = address(uint160(pseudorandomness % MAX_LOCATION));
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
        if (location > MAX_LOCATION) revert ExceedsMaxLocation();

        _transfer(ownerOf(aminalId), address(location), aminalId);
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
    ) internal view override(ERC721) {
        if (!going) revert OnlyMoveWithGoTo();
    }
}
