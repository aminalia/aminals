pragma solidity ^0.8.16;

import {IERC721A} from "chiru-labs/ERC721A/IERC721A.sol";
import {IERC165} from "openzeppelin/utils/introspection/IERC165.sol";

interface IAccessories is IERC721A {
    event BaseURISet(string baseURI);
    event ContractURISet(string contractURI);
    event MinterSet(address newMinter);
    event FundingRecipientSet(address fundingRecipient);

    function mint(address to, uint256 quantity)
        external
        payable
        returns (uint256 fromTokenId);

    /**
     * @dev Withdraws collected ETH to the fundingRecipient.
     */
    function withdrawETH() external;

    /**
     * @dev Sets contract URI.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract, or have the `ADMIN_ROLE`.
     *
     * @param contractURI The contract URI to be set.
     */
    function setContractURI(string memory contractURI) external;

    /**
     * @dev Sets funding recipient address.
     *
     * Calling conditions:
     * - The caller must be the owner of the contract
     *
     * @param fundingRecipient Address to be set as the new funding recipient.
     */
    function setFundingRecipient(address fundingRecipient) external;

    /**
     * @dev Sets minting address
     *
     * Calling conditions:
     * - The caller must be the owner of the contract
     *
     * @param newMinter Address to be set as the new minter
     */
    function setMinter(address newMinter) external;

    /**
     * @dev Returns the contract URI to be used by Opensea.
     *      See: https://docs.opensea.io/docs/contract-level-metadata
     * @return The configured value.
     */
    function contractURI() external view returns (string memory);

    /**
     * @dev Returns the maximum amount of tokens mintable for this edition.
     * @return The configured value.
     */
    function editionMaxMintable() external view returns (uint32);

    function supportsInterface(bytes4 interfaceId)
        external
        view
        override(IERC721A, IERC165)
        returns (bool);
}
