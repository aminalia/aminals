// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@core/interfaces/IAminalCoordinates.sol";
import "@core/interfaces/IAminal.sol";

contract AminalCoordinates is IAminalCoordinates {
    uint160 constant MAX_LOCATION = 1e18;
    
    /* 
      1D location is mapped between 0 and 1e18
      
      2D location splits the uint160 into 2 chunks
      First 30 bits: x
      Next 30 bits: y
    
      3D location splits the uint160 into 3 chunks
      First 20 bits: x
      Next 20 bits: y
      Next 20 bits: z
    */

    uint160 constant BITMASK2D = uint160(0x3FFFFFFF);
    uint160 constant BITMASK3D = uint160(0xFFFFF);

    function maxLocation() external pure returns (uint160) {
        return MAX_LOCATION;
    }

    function locationOf(address aminal, uint256 aminalId)
        public
        view
        returns (uint160 location)
    {
        IAminal aminals = IAminal(aminal);
        if (!aminals.exists(aminalId)) revert AminalDoesNotExist();
        return uint160(aminals.ownerOf(aminalId));
    }

    function locationOf2D(address aminal, uint256 aminalId)
        public
        view
        returns (uint160 x, uint160 y)
    {
        IAminal aminals = IAminal(aminal);
        if (!aminals.exists(aminalId)) revert AminalDoesNotExist();
        uint160 location1D = uint160(aminals.ownerOf(aminalId));
        x = location1D & BITMASK2D;
        y = location1D / 2**30;
    }

    function locationOf3D(address aminal, uint256 aminalId)
        public
        view
        returns (uint160 x, uint160 y, uint160 z)
    {
        IAminal aminals = IAminal(aminal);
        if (!aminals.exists(aminalId)) revert AminalDoesNotExist();
        uint160 location1D = uint160(aminals.ownerOf(aminalId));
        x = location1D & BITMASK3D;
        y = (location1D / 2**20) & BITMASK3D;
        z = location1D / 2**40;
    }

    function addressOfLocation(uint160 location)
        public
        pure
        returns (address locationAddress)
    {
        locationAddress = address(location);
    }
}
