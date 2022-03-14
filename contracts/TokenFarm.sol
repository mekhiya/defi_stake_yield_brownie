// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    /// stakeToken
    /// unStakeToken
    /// issueToken
    /// addAllowedToken
    /// getETHValue
    mapping(address => mapping(address => uint256))
        public tokenToStakerToAmount;
    mapping(address => uint256) public uniqueTokensStaked;
    mapping(address => address) public tokenToPriceFeedAddress;
    address[] public stakers;
    address[] public allowedTokens;
    IERC20 public dappToken;

    constructor(address _dappTOkenAdress) public {
        dappToken = IERC20(_dappTOkenAdress);
    }

    function setPriceFeedAddress(address _token, address _priceFeed)
        public
        onlyOwner
    {
        tokenToPriceFeedAddress[_token] = _priceFeed;
    }

    function issueToken() public onlyOwner {
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            address recepient = stakers[stakersIndex];
            uint256 userTotalValue = getUserTotalValue(recepient);
            dappToken.transfer(recepient, userTotalValue);
        }
    }

    function getUserTotalValue(address _recepient)
        public
        view
        returns (uint256)
    {
        uint256 totalValue = 0;
        for (
            uint256 allowedTotalIndex;
            allowedTotalIndex < allowedTokens.length;
            allowedTotalIndex++
        ) {
            totalValue =
                totalValue +
                getUserSingleTokenTotalValue(
                    _recepient,
                    allowedTokens[allowedTotalIndex]
                );
        }
        return totalValue;
    }

    function getUserSingleTokenTotalValue(address _recepient, address _token)
        public
        view
        returns (uint256)
    {
        // if 1 ETH is USD 2500, then it should return 2500
        // if it has 200 DAI then it should return 200
        if (uniqueTokensStaked[_recepient] <= 0) {
            return 0;
        }
        //we need price of the token, then multiplied to tokenToStakerToAmount[token][user]
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        return ((tokenToStakerToAmount[_token][_recepient] * price) /
            10**decimals);
    }

    function getTokenValue(address _token)
        public
        view
        returns (uint256, uint256)
    {
        // create pricefeed object
        //address
        //abi
        address priceFeedAddress = tokenToPriceFeedAddress[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = priceFeed.decimals();
        return (uint256(price), decimals);
    }

    function stakeToken(uint256 _amount, address _token) public {
        //what tokens can they stake
        //how much can they stake
        require(_amount > 0, "AMount must be more than zero");
        require(isTokenAllowed(_token), "This token currently not allowed!");
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateUniqueTokensStaked(msg.sender, _token);
        tokenToStakerToAmount[_token][msg.sender] =
            tokenToStakerToAmount[_token][msg.sender] +
            _amount;
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function updateUniqueTokensStaked(address _user, address _token) internal {
        if (tokenToStakerToAmount[_token][_user] <= 0) {
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
        }
    }

    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    function isTokenAllowed(address _token) public view returns (bool) {
        for (
            uint256 tokenIndex = 0;
            tokenIndex < allowedTokens.length;
            tokenIndex++
        ) {
            if (_token == allowedTokens[tokenIndex]) {
                return true;
            }
        }
        return false;
    }

    function unStakeTokens(address _token) public {
        uint256 balance = tokenToStakerToAmount[_token][msg.sender];
        require(balance > 0, "Staking Balance cannot be zero");
        IERC20(_token).transfer(msg.sender, balance);
        tokenToStakerToAmount[_token][msg.sender] = 0;
        //Re-Entrancy Attack ????
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;
    }
}
