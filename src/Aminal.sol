// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin/token/ERC721/ERC721.sol";
import "@core/interfaces/IAminal.sol";
import "@core/interfaces/IAminalCoordinates.sol";

import "./AminalVRGDA.sol";

import "../lib/solmate/src/utils/SafeTransferLib.sol";

error AminalDoesNotExist();
error PriceTooLow();
error SenderDoesNotHaveMaxAffinity();
error ExceedsMaxLocation();
error OnlyMoveWithGoTo();
error MaxAminalsSpawned();

// TODO: Refactor Aminals to structs
// TODO: Add getters for prices for each action
// TODO: Add hunger. Hunger acts as a multiplier on top of the units of food
// that someone bought
// TODO: Add poop
// TODO: Add bulk purchase of food and movement
// TODO: Add function that lets us modify metadata for unissued NFTs (and not
// for issued ones)
// TODO: Add personality (where there's a random chance of Aminals doing actions
// different than or in addition to what is specified)
contract Aminal is ERC721, IAminal {
    // Use SafeTransferLib from Solmate V7, which is identical to the
    // SafeTransferLib from Solmate V6 besides the MIT license
    uint160 constant MAX_LOCATION = 1e9;

    uint256 constant MAX_AMINALS = 1e4;

    uint256 currentAminalId;

    bool private going;

    IAminalCoordinates public coordinates;

    modifier goingTo() {
        going = true;
        _;
        going = false;
    }

    struct AminalStruct {
        address favorite;
        address coordinates;
        uint256 totalFed;
        uint256 totalGoTo;
        // We can calculate hunger based on lastFed.
        uint256 lastFed;
        // We can have a fun multiplier like "lastExercised" if we wanted to for
        // the gotos. That would require them to state the max movement they
        // want to occur and be refunded for any unpurchased movements.
        uint256 lastGoTo;
        uint256 lastPooped;
        // This data will not be updated after spawn
        uint256 timeSpawned;
        address spawnedBy;
        // We don't need to track the highest fed or goto amount because we can
        // get that by quering the mappings for the favorite address
        mapping(address => uint256) fedPerAddress;
        mapping(address => uint256) gotoPerAddress;
    }

    // Mapping of Aminal IDs to Aminal structs
    mapping(uint256 => AminalStruct) aminalProperties;
    // Spawning aminals has a global curve, while every other VRGDA is a local
    // curve. This is because we don't have per-aminal spawns. Breeding aminals,
    // for example, would have a local curve.
    AminalVRGDA spawnVRGDA;
    // Set up a mapping of Aminal IDs to VRGDAs. This creates VRGDAs per aminal
    // Each aminal has its own VRGDA curve, to represent its individual level of
    // attention
    mapping(uint256 => AminalVRGDA) feedVRGDA;
    mapping(uint256 => AminalVRGDA) goToVRGDA;

    // TODO: Update this with the timestamp of deployment. This will save gas by
    // maintaing it as a constant instead of setting it in the constructor as a
    // mutable variable.
    int256 constant TIME_SINCE_START = 0;

    // TODO: Update these values to more thoughtful ones
    // A spawn costs 0.01 ETH with a 10% price increase or decrease and an
    // expected spawn rate of two per day
    // TODO: Consider switching spawns to a square root VRGDA
    int256 spawnTargetPrice = 0.01e18;
    int256 spawnPriceDecayPercent = 0.1e18;
    int256 spawnPerTimeUnit = 2e18;

    // A feeding costs 0.001 ETH with a 5% price increase or decrease and an
    // expected feed rate of 4 per hour per aminaml, i.e. 4 * 24 = 96 over 24
    // hours
    int256 feedTargetPrice = 0.001e18;
    int256 feedPriceDecayPercent = 0.05e18;
    int256 feedPerTimeUnit = 96e18;

    // A goto costs 0.001 ETH with a 10% price increase or decrease and an
    // expected goto rate of 4 per hour per aminal, i.e. 4 * 24 = 96 over 24
    // hours
    int256 goToTargetPrice = 0.001e18;
    int256 goToPriceDecayPercent = 0.1e18;
    int256 goToPerTimeUnit = 96e18;

    enum ActionTypes {
        SPAWN,
        FEED,
        GO_TO
    }

    constructor(address _coordinatesMap) ERC721("Aminal", "AMNL") {
        coordinates = IAminalCoordinates(_coordinatesMap);
        spawnVRGDA = new AminalVRGDA(
            spawnTargetPrice,
            spawnPriceDecayPercent,
            spawnPerTimeUnit
        );
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
        if (currentAminalId == MAX_AMINALS) revert MaxAminalsSpawned();
        // Follows the Checks-Effects-Interactions pattern to prevent reentrancy attacks

        // Checks
        // TODO: Refactor this to overload the checkVRGDAInitialized function to
        // only require an action for spawn (no aminalId needed)
        checkVRGDAInitialized(currentAminalId, ActionTypes.SPAWN);
        uint256 price = spawnVRGDA.getVRGDAPrice(
            TIME_SINCE_START,
            currentAminalId
        );
        bool excessPrice = checkExcessPrice(price);

        // Effects
        // Increment the current aminal ID and then spawn the aminal
        currentAminalId++;

        updateAminalSpawnedProperties(currentAminalId, msg.sender, msg.value);

        // Interactions
        if (excessPrice) {
            refundExcessPrice(price);
        }

        emit AminalSpawned(
            msg.sender,
            currentAminalId,
            msg.value,
            senderAffinity
        );
    }

    function feed(uint256 aminalId) public payable {
        checkVRGDAInitialized(aminalId, ActionTypes.FEED);
        uint256 price = spawnVRGDA.getVRGDAPrice(
            TIME_SINCE_START,
            // TODO: Refactor this to use the total food (requires the struct refactor)
            currentAminalId
        );
        bool excessPrice = checkExcessPrice(price);

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

        if (excessPrice) {
            refundExcessPrice(price);
        }

        emit AminalFed(msg.sender, aminalId, msg.value, senderAffinity, newMax);
    }

    // TODO: Consider allowing anyone with affinity to trigger a movement. This
    // allows people to compete using resource exhaustion strategies, where
    // someone with a low affinity drievs up the price so a person with high
    // affinity can't move it.
    function goTo(uint256 aminalId, uint160 location) public goingTo {
        if (!_exists(aminalId)) revert AminalDoesNotExist();
        if (affinity[aminalId][msg.sender] != maxAffinity[aminalId])
            revert SenderDoesNotHaveMaxAffinity();
        if (location > coordinates.maxLocation()) revert ExceedsMaxLocation();

        _transfer(ownerOf(aminalId), address(location), aminalId);
    }

    function updateAminalSpawnedProperties(
        uint256 aminalId,
        address sender,
        uint256 value
    ) internal {
        AminalStruct aminal = aminalProperties[aminalId];
        uint256 pseudorandomness = getPseudorandomValue();

        address location = address(
            uint160(pseudorandomness % coordinates.maxLocation())
        );

        aminal.favorite = sender;
        aminal.coordinates = location;
        uint256 amountFed = value / feedTargetPrice;
        aminal.totalFed = amountFed;
        aminal.lastFed = block.timestamp;
        aminal.timeSpawned = block.timestamp;
        aminal.spawnedBy = sender;
        aminal.fedPerAddress[sender] = amountFed;
        _mint(location, currentAminalId);
    }

    function updateAminalFedProperties(
        uint256 aminalId,
        address sender,
        uint256 value
    ) internal {}

    function updateAminalGoToProperties(
        uint256 aminalId,
        address sender,
        uint256 value
    ) internal {}

    function checkVRGDAInitialized(uint256 aminalId, ActionTypes action)
        internal
    {
        AminalVRGDA vrgda;

        if (action != ActionTypes.SPAWN) {
            vrgda = getVRGDAForNonSpawnAction(action, aminalId);
        } else {
            vrgda = spawnVRGDA;
        }

        if (!vrgda.isInitialized()) {
            initializeVRGDA(aminalId, action);
        }
    }

    function initializeVRGDA(uint256 aminalId, ActionTypes action) internal {
        AminalVRGDA vrgda;
        if (action == ActionTypes.SPAWN) {
            vrgda = new AminalVRGDA(
                spawnTargetPrice,
                spawnPriceDecayPercent,
                spawnPerTimeUnit
            );
        } else if (action == ActionTypes.FEED) {
            vrgda = new AminalVRGDA(
                feedTargetPrice,
                feedPriceDecayPercent,
                feedPerTimeUnit
            );
        } else if (action == ActionTypes.GO_TO) {
            vrgda = new AminalVRGDA(
                goToTargetPrice,
                goToPriceDecayPercent,
                goToPerTimeUnit
            );
        }
    }

    function getVRGDAForNonSpawnAction(ActionTypes action, uint256 aminalId)
        internal
        returns (AminalVRGDA)
    {
        if (action == ActionTypes.FEED) {
            return feedVRGDA[aminalId];
        } else if (action == ActionTypes.GO_TO) {
            return goToVRGDA[aminalId];
        }
    }

    // This takes care of users who have sent too much ETH between seeing a
    // transaction and confirming a transaction.
    // Returns true if there is excess, false if the price is exact, and reverts
    // if the price is too low We cannot refund here because refunding here
    // would open up a re-entrancy attack. We need to refund at the end of the
    // function.
    function checkExcessPrice(uint256 price) internal returns (bool) {
        if (msg.value > price) {
            return true;
        } else if (msg.value < price) {
            revert PriceTooLow();
        } else {
            return false;
        }
    }

    function refundExcessPrice(uint256 price) internal {
        SafeTransferLib.safeTransferETH(msg.sender, msg.value - price);
    }

    // This is neither cryptographically secure nor impossible to manipulate.
    // The fact that Optimism has a single sequencer that processes transactions
    // when they're received helps reduce the chance of manipulation here, but
    // it doesn't eliminate it. Chainlink VRF adds quite a bit of overhead for
    // our lower-security use case.
    // TODO: Update this to be more robust, such as getting the balance of the
    // USDC/ETH and OP/ETH Uniswap V3 pools
    function getPseudorandomValue() internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1),
                        currentAminalId
                    )
                )
            );
    }

    // Protect against someone mining the location key by disallowing any tranfser besides goto
    // TODO: Fix override. The current override does not compile
    function _beforeTokenTransfer(
        address,
        address,
        uint256
    ) internal view {
        if (!going) revert OnlyMoveWithGoTo();
    }
}
