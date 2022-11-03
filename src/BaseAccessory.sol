// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IAccessories} from "@core/interfaces/IAccessories.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ERC721A} from "erc721a/ERC721A.sol";
import {IAminal} from "@core/interfaces/IAminal.sol";

contract BaseAccessory is IAccessories, Ownable, ERC721A {
    // =============================================================
    //                            STORAGE
    // =============================================================

    address public minter; /*Address that is allowed to mint accessories*/
    address public aminalAddress; /*Address of aminals that own accessories*/
    address public fundingRecipient; /*Address to receive proceeds of sales and royalties*/

    uint32 public maxSupply; /*Max amount of accessories that can be minted*/

    bool initialized; /*Track intitialization to prevent double initializing*/

    // Token name
    string private _name;
    // Token symbol
    string private _symbol;

    string private _contractURI;

    // =============================================================
    //                          TEMPLATE CONSTRUCTOR
    // =============================================================
    constructor() ERC721A("AccessoriesTemplate", "TEMP") {
        initialized = true;
    }

    // =============================================================
    //                          CLONE INITIALIZER
    // =============================================================
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address _aminalAddress,
        address _fundingRecipient,
        uint256 supply
    ) public {
        if (initialized) revert AlreadyInitialized();
        initialized = true;
        _name = name_;
        _symbol = symbol_;
        aminalAddress = _aminalAddress;
        maxAccessories = supply;
        fundingRecipient = _fundingRecipient;
    }

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    function withdrawETH() external {
        SafeTransferLib.safeTransferETH(
            fundingRecipient,
            address(this).balance
        );
    }

    function setContractURI(string memory contractURI_) external onlyOwner {
        _contractURI = contractURI_;

        emit ContractURISet(contractURI_);
    }

    function setFundingRecipient(address fundingRecipient_) external onlyOwner {
        if (fundingRecipient_ == address(0)) revert InvalidFundingRecipient();
        fundingRecipient = fundingRecipient_;
        emit FundingRecipientSet(fundingRecipient_);
    }

    function setMinter(address newMinter) external onlyOwner {
        minter = newMinter;

        emit MinterSet(newMinter);
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================
    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    function editionMaxMintable() external view returns (uint32) {
        return maxSupply;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IAccessories, ERC721A, IERC721A)
        returns (bool)
    {
        return
            interfaceId == type(IAccessories).interfaceId ||
            ERC721A.supportsInterface(interfaceId) ||
            interfaceId == this.supportsInterface.selector;
    }
}
