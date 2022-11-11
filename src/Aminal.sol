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
error OnlyMoveWithMove();
error MaxAminalsSpawned();

// TODO: Update IAminal interfaces
// TODO: Add getters for prices for each action
// TODO: Add hunger. Hunger acts as a multiplier on top of the units of food
// that someone bought
// TODO: Add random seed value that is generated upon each action
// TODO: Add function that lets us modify metadata for unissued NFTs (and not
// for issued ones)
// TODO: Add metatransaction support to allow for wrapper contracts
contract Aminal is ERC721 {
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
        uint256 totalMoved;
        // We can calculate hunger based on lastFed.
        uint256 lastFed;
        // We can have a fun multiplier like "lastExercised" if we wanted to for
        // the gotos. That would require them to state the max movement they
        // want to occur and be refunded for any unpurchased movements.
        uint256 lastMoved;
        uint256 lastPooped;
        // This data will not be updated after spawn
        uint256 spawnTime;
        address spawnedBy;
        address spawnedAt;
        // We don't need to track the highest fed or goto amount because we can
        // get that by quering the mappings for the favorite address
        mapping(address => uint256) fedPerAddress;
        mapping(address => uint256) movedPerAddress;
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
    mapping(uint256 => AminalVRGDA) moveVRGDA;

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
    int256 moveTargetPrice = 0.001e18;
    int256 movePriceDecayPercent = 0.1e18;
    int256 movePerTimeUnit = 96e18;

    enum ActionTypes {
        SPAWN,
        FEED,
        MOVE
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
    }

    function feed(uint256 aminalId, uint256 amount) public payable {
        checkVRGDAInitialized(aminalId, ActionTypes.FEED);

        // Reference storage because AminalStruct contains a nested mapping,
        // requires using storage
        AminalStruct storage aminal = aminalProperties[aminalId];
        uint256 startingPrice = feedVRGDA[aminalId].getVRGDAPrice(
            int256(aminal.spawnTime),
            aminal.totalFed
        );
        uint256 endingPrice = feedVRGDA[aminalId].getVRGDAPrice(
            int256(aminal.spawnTime),
            aminal.totalFed + amount
        );

        // If there are any edge cases where ending price is less than starting
        // price, this will revert because the subtraction is checked. Those
        // cases are rather unlikely though.
        uint256 price = (endingPrice - startingPrice) / amount;

        // TODO: Calculate hunger here and scale amount by hunger
        uint256 amountWithHunger = amount;

        updateAminalFedProperties(aminalId, msg.sender, amountWithHunger);

        bool excessPrice = checkExcessPrice(price);

        if (excessPrice) {
            refundExcessPrice(price);
        }

        // TODO: Finish event
        // emit AminalFed(msg.sender, aminalId, msg.value);
    }

    // TODO: Consider allowing anyone with affinity to trigger a movement. This
    // allows people to compete using resource exhaustion strategies, where
    // someone with a low affinity drievs up the price so a person with high
    // affinity can't move it.
    function move(uint256 aminalId, uint160 location) public goingTo {
        checkVRGDAInitialized(aminalId, ActionTypes.MOVE);

        AminalStruct storage aminal = aminalProperties[aminalId];

        // TODO: Calculate distance. Using location as a placeholder here
        uint256 amount = location;
        // TODO: Based on distance, allow them to move via affinity. Maybe
        // affinity is a multiplier?

        uint256 startingPrice = moveVRGDA[aminalId].getVRGDAPrice(
            int256(aminal.spawnTime),
            aminal.totalMoved
        );
        uint256 endingPrice = moveVRGDA[aminalId].getVRGDAPrice(
            int256(aminal.spawnTime),
            aminal.totalMoved + amount
        );

        uint256 price = (endingPrice - startingPrice) / amount;

        updateAminalMoveProperties(aminalId, msg.sender, amount);

        bool excessPrice = checkExcessPrice(price);

        if (excessPrice) {
            refundExcessPrice(price);
        }

        // TODO: Emit AminalSpawned events
    }

    function updateAminalSpawnedProperties(
        uint256 aminalId,
        address sender,
        uint256 value
    ) internal {
        AminalStruct storage aminal = aminalProperties[aminalId];
        uint256 pseudorandomness = getPseudorandomValue();

        address location = address(
            uint160(pseudorandomness % coordinates.maxLocation())
        );

        aminal.favorite = sender;
        aminal.coordinates = location;
        uint256 amountFed = uint256(int256(value) / feedTargetPrice);
        aminal.totalFed = amountFed;
        aminal.lastFed = block.timestamp;
        aminal.spawnTime = block.timestamp;
        aminal.spawnedBy = sender;
        aminal.fedPerAddress[sender] = amountFed;
        _mint(location, currentAminalId);

        // TODO: Finish event
        // emit AminalSpawned(sender, currentAminalId, amountFed);
    }

    function updateAminalFedProperties(
        uint256 aminalId,
        address sender,
        uint256 value
    ) internal {
        AminalStruct storage aminal = aminalProperties[aminalId];
        aminal.totalFed += value;
        aminal.lastFed = block.timestamp;
        aminal.fedPerAddress[sender] = value;

        // If the sender has fed the same amount as the favorite, set the sender
        // as the favorite because the sender is more recent
        if (
            aminal.fedPerAddress[sender] >=
            aminal.fedPerAddress[aminal.favorite]
        ) {
            aminal.favorite = sender;
            // TODO: Emit FavoriteUpdated event
        }
        // TODO: Emit event
    }

    function updateAminalMoveProperties(
        uint256 aminalId,
        address sender,
        uint256 value
    ) internal {
        AminalStruct storage aminal = aminalProperties[aminalId];
        aminal.totalMoved += value;
        aminal.lastMoved = block.timestamp;
        aminal.movedPerAddress[sender] = value;

        // TODO: Emit event
    }

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
        } else if (action == ActionTypes.MOVE) {
            vrgda = new AminalVRGDA(
                moveTargetPrice,
                movePriceDecayPercent,
                movePerTimeUnit
            );
        }
    }

    function getVRGDAForNonSpawnAction(ActionTypes action, uint256 aminalId)
        internal
        returns (AminalVRGDA)
    {
        if (action == ActionTypes.FEED) {
            return feedVRGDA[aminalId];
        } else if (action == ActionTypes.MOVE) {
            return moveVRGDA[aminalId];
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
        if (!going) revert OnlyMoveWithMove();
    }
}
