pragma solidity ^0.8.16;

interface IAminalCoordinates {
    error AminalDoesNotExist();

    function addressOfLocation(uint160 location)
        external
        view
        returns (address);

    function locationOf(address aminal, uint256 aminalId)
        external
        view
        returns (uint160 location);

    function locationOf2D(address aminal, uint256 aminalId)
        external
        view
        returns (uint160 x, uint160 y);

    function locationOf3D(address aminal, uint256 aminalId)
        external
        view
        returns (
            uint160 x,
            uint160 y,
            uint160 z
        );

    function maxLocation() external view returns (uint160);
}
