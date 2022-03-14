import pytest
from brownie import accounts, network, config, exceptions
from scripts.helpful_scripts import (
    INITIAL_PRICE_FEED_VALUE,
    LOCAL_BLOCKCHAIN_ENVIRONMENTS,
    get_account,
    get_contract,
)
from scripts.deploy import deploy_token_farm_and_dapp_token


def test_set_price_feed_contract():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip("Only for local testing!")

    account = get_account()
    non_owner = get_account(index=1)
    token_farm, dapp_token = deploy_token_farm_and_dapp_token()
    # Act
    price_feed_address = get_contract("eth_usd_price_feed")
    token_farm.setPriceFeedAddress(
        dapp_token.address, price_feed_address, {"from": account}
    )
    # Assert
    # assert (
    #     token_farm.tokenToPriceFeedAddress[dapp_token]
    #     == config["netowrks"][network.show_active()]["eth_usd_price_feed"]
    # )
    assert token_farm.tokenToPriceFeedAddress(dapp_token.address) == price_feed_address
    with pytest.raises(exceptions.VirtualMachineError):
        token_farm.setPriceFeedAddress(
            dapp_token.address, price_feed_address, {"from": non_owner}
        )


def test_stake_tokens(amount_staked):
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip("Only for local testing!")

    account = get_account()
    token_farm, dapp_token = deploy_token_farm_and_dapp_token()
    # Act
    dapp_token.approve(token_farm.address, amount_staked, {"from": account})
    token_farm.stakeToken(amount_staked, dapp_token.address, {"from": account})
    # Assert
    assert (
        # tokenToStakerToAmount[_token][_recepient]
        token_farm.tokenToStakerToAmount(dapp_token, account.address)
        == amount_staked
    )
    assert token_farm.uniqueTokensStaked(account.address) == 1
    assert token_farm.stakers(0) == account.address
    return token_farm, dapp_token


def test_issue_tokens(amount_staked):
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip("Only for local testing!")

    account = get_account()
    token_farm, dapp_token = test_stake_tokens(amount_staked)
    starting_balance = dapp_token.balanceOf(account.address)
    print(f"starting_balance is : {starting_balance}")
    print(f"INITIAL_PRICE_FEED_VALUE is : {INITIAL_PRICE_FEED_VALUE}")
    # Act
    token_farm.issueToken({"from": account})
    # we are staking 1 dapp_token, which is equal to 1 ETH in price
    # since the price of ETH is around $2000
    # so we should get 2,000 dapp tokens in reward
    new_balance = dapp_token.balanceOf(account.address)
    print(f"New dapp_token.balance is : {new_balance}")
    assert (
        dapp_token.balanceOf(account.address)
        == starting_balance + INITIAL_PRICE_FEED_VALUE
    )
