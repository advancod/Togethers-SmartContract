// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "Ownable.sol";

contract Administration is Ownable {

  /**
   * @notice Map each satblecoin address accepted in boxes with one home stablecoin
   */
  mapping (address => uint8) public mappAllowCryptoForCategory;
  /**
   * @notice Enable or disable token use in the app
   */
  mapping (address => bool) public mappCryptoEnable;
  /**
   * @notice every user address has a unique name
   */
  mapping (uint => address) public checkNameUnicity;
  /**
   * @notice Map each satblecoin address accepted in boxes
   */
  mapping (address => string) public mappAddressToUser;
  /**
   * @notice the password security is SHA1 hashed and send from front and hashed again in keccak to be private saved
   */
  /**
   * @notice describe the type of home stablecoins
   */
  mapping (uint => string) public stablecoinType;

  /**
   * @notice the list of every token that can be used in the contract
   */
  address[] cryptoList;
  /**
   * @notice the liste of every home stablecoin, one category (USD,EUR) is unique
   */
  address[] homeStableList;

  /**
   * @notice the required decimal value of a homestablecoin
   */
  uint8 public constant max = 18;

  /**
   * @notice struct of a ERC20 object
   * @notice Category: if not 0 it is the index of homestablecoin a stablecoin is for
   * @notice status: is enable in the app or not
   */
  struct erc20
  {
    string symbol;
    string name;
    uint decimals;
    bool status;
    uint8 category;
    uint balance;
    uint balanceContract;
  }
  /**
   * @notice Verify the availability of a username choosed by a user address
   * @return 1 if the username is available, 0 otherwise
   */
    function verifyUserAvailability(string memory _pseudo) public view returns (uint)
    {
      uint currentID = returnHash(_pseudo);
      if (checkNameUnicity[currentID] == address(0))
      {
        return 1;
      }
      return 0;
    }

  /**
   * @notice enable or disable token use in the list of token
   * @param crypto: the token address
   */
  function enableCrypto(address crypto) public onlyOwner
  {
    require(crypto != address(0));
    require(checkCryptoToList(crypto) == false);
    if (mappCryptoEnable[crypto] == false)
    {
      mappCryptoEnable[crypto] = true;
    }
    else
    {
      mappCryptoEnable[crypto] = false;
    }
  }

  /**
   * @notice Add a token in list
   * @notice the token should not to be in the list already
   * @notice the address should be a token address
   * @param crypto: the token address
   */
  function addCryptoToList(address crypto) public onlyOwner
  {
    require(crypto != address(0));
    require(checkCryptoToList(crypto) == true);
    require(External1(crypto).decimals() != 0);
    cryptoList.push(crypto);
  }

  /**
   * @notice Private function that control the used of crypto
   * @param crypto: the token address
   * @return true if the token is in the list, false if it is note
   */
  function checkCryptoToList(address crypto) private view returns (bool)
  {
    bool add = true;
    for(uint i = 0 ; i < cryptoList.length ; i++)
    {
      if (cryptoList[i] == crypto)
      {
        add = false;
        break;
      }
    }
    return add;
  }

  /**
   * @notice determine the category of a stablecoin then his corresponding home stablecoin
   * @param crypto: the token address
   * @param category: the home stablecoin number
   */
  function allowCryptoForCategory(address crypto, uint8 category) public onlyOwner
  {
    require(category != 0 && category < homeStableList.length);
    require(mappCryptoEnable[crypto] == true);
    require(External1(crypto).decimals() <= max);
    for(uint i = 0 ; i < homeStableList.length ; i++)
    {
      if(homeStableList[i] == crypto)
      {
        require(i == category);
        break;
      }
    }
    mappAllowCryptoForCategory[crypto] = category;
  }

  /**
   * @notice add a new home stablecoin to the list
   * @notice should be a new created token mintable by this contract
   * @param crypto: the home stablecoin address
   * @param currency: the type of the stablecoin
   */
  function createNewHomeStable(address crypto, string memory currency) public onlyOwner
  {
    require(External1(crypto).decimals() == max);
    require(External1(crypto).totalSupply() == 0);
    require(External1(crypto).Escrow() == address(this));
    stablecoinType[homeStableList.length] = currency;
    homeStableList.push(crypto);
  }

  /**
   * @return the list of used ERC20
   */
  function getCryptoList() view public returns (address[] memory)
  {
    return cryptoList;
  }

  /**
   * @return the list of home stablecoins
   */
  function getStableCoinList() view public returns (address[] memory)
  {
    return homeStableList;
  }

}