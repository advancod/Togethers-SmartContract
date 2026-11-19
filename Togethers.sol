// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "Administration.sol";

contract Togethers is Administration {

  /**
  * @notice Each group is mapped to a unique number
   */
  mapping (uint => string) public mappGroupIDToGroupName;
  /**
   * @notice each user address have info in group
   */
  mapping (uint => mapping (address => profile)) private mappProfileInGroup;
  /**
   * @notice the list of groups numbers for a user address
   */
  mapping (address => uint[]) private mappGroupsForAddress;
  /**
   * @notice the list of user address in a group
   */
  mapping (uint => address[]) private mappUsersInGroup;
  /**
   * @notice global exchange of crypto between peers
   */
  mapping (address => mapping (address => mapping (uint8 => uint))) private mappPeerToPeerStats;
  /**
   * @notice crypto there are in a box
   */
  mapping (uint => mapping (address => mapping (uint8 => uint))) public mappProfileStats;
  /**
   * @notice crypto a user has given in a box
   */
  mapping (uint => mapping (address => mapping (uint8 => uint))) public mappIdStats;
  /**
   * @notice flag telling if a user have asked to be part of group
   */
  mapping (address => mapping (uint => bool)) private mappAskForAdd;
  /**
   * @notice list of membership demand in a group
   */
  mapping (uint => address[]) private mappAskMembershipList;

  /**
   * @notice iterating box number
   */
  uint public id;

  /**
   * @notice state of a user in a group
   * @notice id: number of the demand
   * @notice isMember: the address is member of the group
   * @notice open: the box demand is open
   * @notice description: the description of the demand
   * @notice owner: the user is the administrator of the group
   */
  struct profile
  {
    bool isMember;
    bool open;
    bool owner;
    bool ask;
    string description;
    string name;
    uint id;
  }

  /**
   * @notice struct used for stats
   */
  struct stats
  {
    uint In;
    uint Out;
  }

  /**
   * @notice iterating groupID
   */
  uint public groupNumber;

  /**
   * @notice iterating groupID
   * @notice "Togethers" user name is app property
   * @notice ethers are special crypto category
   */
  constructor() {
    owner = msg.sender;
    checkNameUnicity[returnHash("Togethers")] = address(this);
    homeStableList.push(address(0));
    mappAllowCryptoForCategory[address(0)] = 0;
    stablecoinType[0] = 'NaN';
  }

  /**
   * @notice a user have to ask a group to allow the admin of the group to add him
   * @param _groupID the group number to ask
   */
  function ask(uint _groupID) public
  {
    require(_groupID > 0 && _groupID <= groupNumber, "Unknown group");
    require(mappProfileInGroup[_groupID][msg.sender].isMember == false);
    require(mappProfileInGroup[_groupID][msg.sender].ask == false);
    mappProfileInGroup[_groupID][msg.sender].ask = true;
    bool isInList;
    for (uint i = 0; i < mappAskMembershipList[_groupID].length; i++)
    {
      if (mappAskMembershipList[_groupID][i] == msg.sender)
      {
        isInList = true;
        break;
      }
    }
    if (isInList == false)
    {
      mappAskMembershipList[_groupID].push(msg.sender);
    }
  }

  /**
   * @notice an admin of a group can give his power to an other member of the group
   * @notice an admin of a group can add or remove a member of a group
   * @param _groupID the group number concerned
   * @param newOwner the address of the new owner
   */
  function transferGroupOwnership(uint _groupID, address newOwner) public
  {
    require(mappProfileInGroup[_groupID][msg.sender].owner == true);
    require(mappProfileInGroup[_groupID][newOwner].isMember == true);
    mappProfileInGroup[_groupID][msg.sender].owner = false;
    mappProfileInGroup[_groupID][newOwner].owner = true;
  }

  /**
   * @notice registering a user address with his username
   * @notice the user name is hashed to be unique
   * @param _pseudo user name choosen
   */
  function setUser(string memory _pseudo) public
  {
    require(bytes(_pseudo).length > 0, "Empty pseudo");
    require(bytes(mappAddressToUser[msg.sender]).length == 0, "Already registered, use changeUserName");
    uint currentID = returnHash(_pseudo);
    require(checkNameUnicity[currentID] == address(0));
    checkNameUnicity[currentID] = msg.sender;
    mappAddressToUser[msg.sender] = _pseudo;
  }

  /**
   * @notice a user can change is username in the network
   * @param _pseudo new pseudo choosen
   */
  function changeUserName(string memory _pseudo) public
  {
    require(bytes(_pseudo).length > 0, "Empty pseudo");
    require(bytes(mappAddressToUser[msg.sender]).length > 0, "Not registered, use setUser");
    uint currentID = returnHash(_pseudo);
    require(checkNameUnicity[currentID] == address(0));
    checkNameUnicity[returnHash(mappAddressToUser[msg.sender])] = address(0);
    checkNameUnicity[currentID] = msg.sender;
    mappAddressToUser[msg.sender] = _pseudo;
  }

  /**
   * @notice a user can create groups whithout any restriction
   * @notice the group ID is iterating and unique
   * @notice the creator is member and admin of a group
   * @param _groupName new group name choosen by the creator
   */
  function createGroup(string memory _groupName) public
  {
    groupNumber += 1;
    mappProfileInGroup[groupNumber][msg.sender].owner = true;
    mappProfileInGroup[groupNumber][msg.sender].ask = true;
    mappGroupIDToGroupName[groupNumber] = _groupName;
    addMember(groupNumber,msg.sender);
  }

  /**
   * @notice private function used by createGroup and createProfile
   * @notice add a member to a group by adding user to group list and group to user list
   * @notice the member is added once, then just the flag is used to make add and remove cheaper
   * @param _groupID group member concerned
   * @param _key new member address
   */
  function addMember(uint _groupID, address _key) private
  {
    require(mappProfileInGroup[_groupID][msg.sender].owner == true);
    bool isRegisterd;
    for (uint i = 0; i < mappGroupsForAddress[_key].length; i++)
    {
      if (mappGroupsForAddress[_key][i] == _groupID)
      {
        isRegisterd = true;
        break;
      }
    }
    if (isRegisterd == false)
    {
      mappGroupsForAddress[_key].push(_groupID);
      mappUsersInGroup[_groupID].push(_key);
    }
    mappProfileInGroup[_groupID][_key].isMember = true;
    mappProfileInGroup[_groupID][_key].ask = false;
  }

  /**
   * @notice add a user to a group by admin if the user has asked
   * @param groupID the number of the group where ethe user will be added
   * @param _key is the address of the new user
   */
  function createProfile(uint groupID, address _key) public
  {
    require(mappProfileInGroup[groupID][_key].isMember == false);
    require(mappProfileInGroup[groupID][_key].ask == true);
    addMember(groupID,_key);
  }

  /**
   * @notice opening of a box demand by a user in a group
   * @param groupID the number of the group where the box is open
   * @param _description a description reason of the opening
   */
  function askForFunds(uint groupID, string memory _description) public
  {
    require(mappProfileInGroup[groupID][msg.sender].open == false);
    require(mappProfileInGroup[groupID][msg.sender].isMember == true);
    id += 1;
    mappProfileInGroup[groupID][msg.sender].open = true;
    mappProfileInGroup[groupID][msg.sender].description = _description;
    mappProfileInGroup[groupID][msg.sender].id = id;
  }

  /**
   * @notice a member of a group can pay an open box in ether or stablecoin
   * @notice the stats are made
   * @notice the stablecoins amounts are converted id homestablecoin amonunt
   * @param _publicKey the address of box owner
   * @param groupID the group of the box
   * @param _tokenAmount the token amount if apply
   * @param _crypto the token address if apply
   */
  function payForFunds(address _publicKey,  uint groupID, uint _tokenAmount, address _crypto) public payable
  {
    require(mappProfileInGroup[groupID][msg.sender].isMember == true, "Sender not member");
    require(mappProfileInGroup[groupID][_publicKey].isMember == true, "Target not member");
    require(mappProfileInGroup[groupID][_publicKey].open == true, "Box not open");
    uint amount;
    uint8 category;
    if (msg.value > 0)
    {
      // ether payment: always category 0, whatever token address is passed
      require(_crypto == address(0), "Ether payment with token address");
      amount = msg.value;
      category = 0;
    }
    else
    {
      require(_tokenAmount > 0, "Zero amount");
      require(mappCryptoEnable[_crypto] == true, "Token disabled");
      category = mappAllowCryptoForCategory[_crypto];
      // a token without category would otherwise be credited as ether
      require(category != 0, "Token without category");
      for(uint i = 0 ; i < homeStableList.length ; i++)
      {
        require(homeStableList[i] != _crypto, "Home stablecoin not accepted");
      }
      amount = _tokenAmount;
      _safeTransferFrom(_crypto, msg.sender, address(this), _tokenAmount);
      uint decimals = External1(_crypto).decimals();
      if (decimals < max)
      {
        amount = amount * 10**(max - decimals);
      }
    }
    mappProfileStats[groupID][_publicKey][category] += amount;
    mappPeerToPeerStats[msg.sender][_publicKey][category] += amount;
    mappIdStats[mappProfileInGroup[groupID][_publicKey].id][msg.sender][category] += amount;
  }

  /**
   * @notice a member can close his opened box in a group
   * @notice the member withdraw ethers and homestablecoins
   * @notice the stablecoins amounts are converted id homestablecoin amonunt
   * @notice global box stats are initialized
   * @param groupID the group of the box
   */
  function withdrawFunds(uint groupID) public
  {
    require(mappProfileInGroup[groupID][msg.sender].isMember == true, "Not member");
    require(mappProfileInGroup[groupID][msg.sender].open == true, "No open box");
    mappProfileInGroup[groupID][msg.sender].open = false;
    uint etherAmount = mappProfileStats[groupID][msg.sender][0];
    // effects before interactions: balances are reset before any external call (reentrancy)
    mappProfileStats[groupID][msg.sender][0] = 0;
    for(uint8 i = 1 ; i < homeStableList.length ; i++)
    {
      uint value = mappProfileStats[groupID][msg.sender][i];
      if (value > 0)
      {
        mappProfileStats[groupID][msg.sender][i] = 0;
        require(External1(homeStableList[i]).mintExternal(msg.sender, value), "Mint failed");
      }
    }
    if (etherAmount > 0)
    {
      (bool success, ) = payable(msg.sender).call{value: etherAmount}("");
      require(success, "Transfer failed");
    }
  }

  /**
   * @notice stablecoins can be changed here by category
   * @notice the stablecoin have to be enable
   * @notice fees are applied here
   * @notice input amount have to be converted in 18 decimals
   * @param _tokenAmount the aount of token exchange one to one (in 18 decimals)
   * @param _crypto1 the address of the income token
   * @param _crypto2 the address of the outcome token
   */
  function changeToken(uint _tokenAmount, address _crypto1, address _crypto2) public
  {
    require(_tokenAmount > 0, "Zero amount");
    require(_crypto1 != _crypto2, "Same token");
    require(mappCryptoEnable[_crypto1] == true && mappCryptoEnable[_crypto2] == true, "Token disabled");
    uint8 category = mappAllowCryptoForCategory[_crypto1];
    require(category != 0 && category == mappAllowCryptoForCategory[_crypto2], "Different categories");
    uint scale1 = 10**(max - External1(_crypto1).decimals());
    uint scale2 = 10**(max - External1(_crypto2).decimals());
    // refuse amounts lost by rounding, otherwise dust could be taken for free
    require(_tokenAmount % scale1 == 0 && _tokenAmount % scale2 == 0, "Amount not representable in both tokens");
    _safeTransferFrom(_crypto1, msg.sender, address(this), _tokenAmount / scale1);
    _safeTransfer(_crypto2, msg.sender, _tokenAmount / scale2);
  }

  /**
   * @notice transferFrom that also accepts tokens returning no value (USDT style)
   */
  function _safeTransferFrom(address _token, address _from, address _to, uint _value) private
  {
    (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(External1.transferFrom.selector, _from, _to, _value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");
  }

  /**
   * @notice transfer that also accepts tokens returning no value (USDT style)
   */
  function _safeTransfer(address _token, address _to, uint _value) private
  {
    (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(External1.transfer.selector, _to, _value));
    require(success && (data.length == 0 || abi.decode(data, (bool))), "transfer failed");
  }

  /**
   * @notice remove a user from a group by the owner
   * @param _publicKey the address of the user to remove
   * @param groupID the number of the concerned group
   */
  function removeMember(address _publicKey, uint groupID) public
  {
    require(_publicKey != msg.sender);
    require(mappProfileInGroup[groupID][msg.sender].isMember == true);
    require(mappProfileInGroup[groupID][msg.sender].owner == true);
    deleteProfile(groupID,_publicKey);
  }

  /**
   * @notice a user can quit a group when he wants
   * @param _groupID the number of the concerned group
   */
  function quitGroup(uint _groupID) public
  {
    if ( mappProfileInGroup[_groupID][msg.sender].open == true )
    {
      withdrawFunds(_groupID);
    }
    if (mappProfileInGroup[_groupID][msg.sender].owner == true)
    {
      for (uint i = 0; i < mappUsersInGroup[_groupID].length; i++)
      {
        if (mappProfileInGroup[_groupID][mappUsersInGroup[_groupID][i]].isMember == true && mappUsersInGroup[_groupID][i] != msg.sender)
        {
          mappProfileInGroup[_groupID][mappUsersInGroup[_groupID][i]].owner = true;
          break;
        }
      }
      mappProfileInGroup[_groupID][msg.sender].owner = false;
    }
    deleteProfile(_groupID,msg.sender);
  }

  /**
   * @notice private function to quit a group or remove user
   * @param _groupID the number of the concerned group
   * @param _publicKey the address of the concerned user
   */
  function deleteProfile(uint _groupID, address _publicKey) private
  {
    require(mappProfileInGroup[_groupID][_publicKey].isMember == true);
    require(mappProfileInGroup[_groupID][_publicKey].open == false);
    mappProfileInGroup[_groupID][_publicKey].isMember = false;
  }

  /**
   * @notice returns the list of groups of a user
   * @return a uint list
   */
  function getGroups() view public returns (uint[] memory)
  {
    return mappGroupsForAddress[msg.sender];
  }

  /**
   * @notice returns the list of members in a group
   * @param _group the number of the concerned group
   * @return a address list
   */
  function getProfiles(uint _group) view public returns (address[] memory)
  {
    require(mappProfileInGroup[_group][msg.sender].isMember == true);
    return mappUsersInGroup[_group];
  }

  /**
   * @notice returns the linformation of a erc20 token
   * @param _crypto the address of the concerned ERC20
   * @return a erc20 struct
   */
  function getCryptoInfo(address _crypto) view public returns (erc20 memory)
  {
    uint decimals = External1(_crypto).decimals();
    string memory symbol = External1(_crypto).symbol();
    string memory name = External1(_crypto).name();
    bool status = mappCryptoEnable[_crypto];
    uint8 category = mappAllowCryptoForCategory[_crypto];
    uint balance = External1(_crypto).balanceOf(msg.sender);
    uint balanceContract = External1(_crypto).balanceOf(address(this));
    return erc20(symbol,name,decimals,status,category,balance,balanceContract);
  }

  /**
   * @notice returns global exchange betwwen peers for one crypto
   * @param to the address of the user the sender want see the stats
   * @param crypto the address of ERC20
   * @return a stats struct
   */
  function getStats(address to, uint8 crypto) view public returns (stats memory)
  {
    uint Out = mappPeerToPeerStats[msg.sender][to][crypto];
    uint In = mappPeerToPeerStats[to][msg.sender][crypto];
    return stats(In,Out);
  }

  /**
   * @notice returns the state of a box for one crypto with the current donation of the sender
   * @param groupID the number of group of the box
   * @param _user the address of the user of the box
   * @param crypto the address of ERC20 token
   * @return a stats struct
   */
  function getProfileStats(uint groupID, address _user, uint8 crypto) view public returns (stats memory)
  {
    require(mappProfileInGroup[groupID][msg.sender].isMember == true);
    uint In = mappProfileStats[groupID][_user][crypto];
    uint Out = mappIdStats[mappProfileInGroup[groupID][_user].id][msg.sender][crypto];
    return stats(In,Out);
  }

  /**
   * @notice returns the information of a user in a group
   * @param groupID the number of group
   * @param _user the address of the user
   * @notice you have to be a member of the group to know these info
   * @return a profile struct
   */
  function getProfileInGroup(uint groupID, address _user) view public returns (profile memory)
  {
    return profile(mappProfileInGroup[groupID][_user].isMember,
      mappProfileInGroup[groupID][_user].open,
      mappProfileInGroup[groupID][_user].owner,
      mappProfileInGroup[groupID][_user].ask,
      mappProfileInGroup[groupID][_user].description,
      mappAddressToUser[_user],
      mappProfileInGroup[groupID][_user].id);
  }

  /**
   * @notice the list of pending membership demand to a group
   * @param groupID the number of group of the box
   * @return an address list
   */
  function getAskMembershipList(uint groupID) view public returns (address[] memory)
  {
    require(mappProfileInGroup[groupID][msg.sender].isMember == true);
    require(mappProfileInGroup[groupID][msg.sender].owner == true);
    return mappAskMembershipList[groupID];
  }

}