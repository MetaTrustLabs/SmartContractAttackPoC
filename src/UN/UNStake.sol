/**
 *Submitted for verification at BscScan.com on 2023-06-06
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;
interface IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}
contract Ownable {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    constructor() {
        _transferOwnership(_msgSender());
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
contract Manager is Ownable {
    address public manager;
    modifier onlyManager() {
        require(
            owner() == _msgSender() || manager == _msgSender(),
            "Ownable: Not Manager"
        );
        _;
    }
    function setManager(address account) public virtual onlyManager {
        manager = account;
    }
}
contract UNStake is Manager {
    struct UserInfo {
        bool isExist;
        uint balance;
        uint rewardTotal;
        uint balanceUSDT;
        uint rewardTotalUSDT;
        uint balanceInvite;
        uint rewardInviteUSDT;
        uint registerTime;
        address refer;
    }
    struct RewardInfo {
        uint v1;
        uint v1Debt;
        uint v1Reward;
        uint v2;
        uint v2Debt;
        uint v2Reward;
        uint v3;
        uint v3Debt;
        uint v3Reward;
    }
    struct StakeInfo {
        bool isValid;
        uint index;
        uint userIndex;
        uint amount;
        uint rate;
        uint startTime;
        uint lastTime;
        uint cancelTime;
        uint reward;
        address owner;
    }
    uint public stakeTotal;
    mapping(uint => StakeInfo) public stakes;
    mapping(address => mapping(uint => uint)) public userStakeIndex;
    mapping(address => uint) public userStakes;
    uint public userTotal;
    mapping(address => UserInfo) public users;
    mapping(address => RewardInfo) public rewards;
    mapping(uint => address) public userAdds;
    mapping(address => mapping(uint => address)) public userInvites;
    mapping(address => uint) public userInviteTotals;
    mapping(address => bool) public isBlackList;
    uint _dayTimes = 86400;
    uint private _totalRelease;
    uint private _totalInvite;
    uint private _totalReward;
    uint private _totalIDO;
    uint private _totalWithdraw;
    uint private _totalWithdrawUSDT;
    uint private _v1Total;
    uint private _v2Total;
    uint private _v3Total;
    uint private _v1PerReward;
    uint private _v2PerReward;
    uint private _v3PerReward;
    uint private _feeWithdraw;
    uint private _minWithdraw;
    uint[3] private _stakeAmounts = [200e18, 500e18, 1000e18];
    uint[3] private _stakeRates = [200, 250, 333];
    uint[2] private _inviteRates = [700, 300];
    address private _stakeWallet;
    address private _feeTo;
    IERC20 private _UN;
    IERC20 private _USDT;
    event BindRefer(address account, address refer);
    event BalanceChange(
        address account,
        uint category,
        uint amount,
        uint actual,
        uint balance
    );
    constructor() {
        manager = 0x4A59F0dc27a4a75dbbb42C64e6F3F0b847f4E765;
        _feeTo = 0x14F77d52222B773C0309cdC53f43F87D893A0607;
        _stakeWallet = 0x14F77d52222B773C0309cdC53f43F87D893A0607;
        _USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
        users[0x797D22e9FA8F707ba061b79f278f3BdF61015D31].isExist = true;
        transferOwnership(manager);
    }
    function withdrawToken(IERC20 token, uint amount) public onlyManager {
        token.transfer(msg.sender, amount);
    }
    function setTokenAdd(address wallet, address feeTo) public onlyManager {
        _stakeWallet = wallet;
        _feeTo = feeTo;
    }
    function setConfig(uint feeRate, uint minWith) public onlyManager {
        _feeWithdraw = feeRate;
        _minWithdraw = minWith;
    }
    function setStakeAmount(
        uint data1,
        uint data2,
        uint data3
    ) public onlyManager {
        _stakeAmounts[0] = data1;
        _stakeAmounts[1] = data2;
        _stakeAmounts[2] = data3;
    }
    function setStakeRates(
        uint data1,
        uint data2,
        uint data3
    ) public onlyManager {
        _stakeRates[0] = data1;
        _stakeRates[1] = data2;
        _stakeRates[2] = data3;
    }
    function setInviteRates(uint data1, uint data2) public onlyManager {
        _inviteRates[0] = data1;
        _inviteRates[1] = data2;
    }
    function setIsBlackList(address account, bool data) public onlyManager {
        isBlackList[account] = data;
    }
    function setNode(
        address account,
        uint level,
        bool data
    ) public onlyManager {
        require(users[account].isExist, "User Not Exist");
        updateUser(account);
        RewardInfo storage info = rewards[account];
        if (level == 1) {
            info.v1 = data ? 1 : 0;
            info.v1Debt = (info.v1 * _v1PerReward) / 1e12;
            if (data) _v1Total++;
            else if (_v1Total > 0) _v1Total--;
        } else if (level == 2) {
            info.v2 = data ? 1 : 0;
            info.v2Debt = (info.v2 * _v2PerReward) / 1e12;
            if (data) _v2Total++;
            else if (_v2Total > 0) _v2Total--;
        } else if (level == 3) {
            info.v3 = data ? 1 : 0;
            info.v3Debt = (info.v3 * _v3PerReward) / 1e12;
            if (data) _v3Total++;
            else if (_v3Total > 0) _v3Total--;
        }
        emit BalanceChange(
            account,
            8,
            level,
            data ? 1 : 0,
            users[account].rewardTotal
        );
    }
    function getTokenAdd()
        public
        view
        returns (address stakeWallet, address feeTo)
    {
        stakeWallet = _stakeWallet;
        feeTo = _feeTo;
    }
    function getConfig()
        public
        view
        returns (
            uint minWithdraw,
            uint feeWithdraw,
            uint totalRelease,
            uint totalInvite,
            uint totalReward,
            uint totalDeposit,
            uint totalWithdraw,
            uint totalWithdrawUSDT,
            uint[3] memory stakeAmounts,
            uint[3] memory stakeRates,
            uint[2] memory inviteRates
        )
    {
        minWithdraw = _minWithdraw;
        feeWithdraw = _feeWithdraw;
        totalRelease = _totalRelease;
        totalInvite = _totalInvite;
        totalReward = _totalReward;
        totalDeposit = _totalIDO;
        totalWithdraw = _totalWithdraw;
        totalWithdrawUSDT = _totalWithdrawUSDT;
        stakeAmounts = _stakeAmounts;
        stakeRates = _stakeRates;
        inviteRates = _inviteRates;
    }
    function getUserInfo(
        address account
    )
        public
        view
        returns (
            UserInfo memory user,
            RewardInfo memory idoInfo,
            StakeInfo[] memory infos
        )
    {
        user = users[account];
        idoInfo = rewards[account];
        uint256 total = userStakes[account];
        infos = new StakeInfo[](total);
        uint256 rewardTotal;
        for (uint256 i = 0; i < total; i++) {
            uint256 index = userStakeIndex[account][i + 1];
            if (stakes[index].isValid && stakes[index].owner == account) {
                StakeInfo memory stake = stakes[index];
                uint256 timestamp = block.timestamp - stake.lastTime;
                uint256 reward = (stake.rate * stake.amount * timestamp) /
                    (10000 * _dayTimes);
                if (stake.amount <= stake.reward) {
                    stake.isValid = false;
                } else {
                    if (reward > stake.amount - stake.reward) {
                        reward = stake.amount - stake.reward;
                        stake.isValid = false;
                    }
                    rewardTotal += reward;
                    stake.lastTime = block.timestamp;
                    stake.reward += reward;
                }
            }
        }
        if (rewardTotal > 0) {
            user.balanceUSDT += rewardTotal;
            user.rewardTotalUSDT += rewardTotal;
        }
        rewardTotal = 0;
        RewardInfo memory info = rewards[account];
        if (info.v1 > 0) {
            uint reward = (info.v1 * _v1PerReward) / 1e12 - info.v1Debt;
            info.v1Reward + reward;
            info.v1Debt = (info.v1 * _v1PerReward) / 1e12;
            rewardTotal += reward;
        }
        if (info.v2 > 0) {
            uint reward = (info.v2 * _v2PerReward) / 1e12 - info.v2Debt;
            info.v2Reward + reward;
            info.v2Debt = (info.v2 * _v2PerReward) / 1e12;
            rewardTotal += reward;
        }
        if (info.v3 > 0) {
            uint reward = (info.v3 * _v3PerReward) / 1e12 - info.v3Debt;
            info.v3Reward + reward;
            info.v3Debt = (info.v3 * _v3PerReward) / 1e12;
            rewardTotal += reward;
        }
        if (rewardTotal > 0) {
            user.balance += rewardTotal;
            user.rewardTotal += rewardTotal;
        }
    }
    function getUserInfos(
        address[] calldata accounts
    ) public view returns (UserInfo[] memory infos, RewardInfo[] memory idos) {
        infos = new UserInfo[](accounts.length);
        for (uint256 j = 0; j < accounts.length; j++) {
            address account = accounts[j];
            (UserInfo memory user, RewardInfo memory idoInfo, ) = getUserInfo(
                account
            );
            infos[j] = user;
            idos[j] = idoInfo;
        }
    }
    function getInvitesInfo(
        address account
    ) public view returns (address[] memory invites, UserInfo[] memory infos) {
        invites = new address[](userInviteTotals[account]);
        infos = new UserInfo[](userInviteTotals[account]);
        for (uint i = 0; i < userInviteTotals[account]; i++) {
            invites[i] = userInvites[account][i + 1];
            infos[i] = users[invites[i]];
        }
    }
    function ido(uint index, address refer) public {
        address account = msg.sender;
        require(index < 3, "Index Error");
        if (index == 0) require(rewards[account].v1 == 0, "Has IDO");
        if (index == 1) require(rewards[account].v2 == 0, "Has IDO");
        if (index == 2) require(rewards[account].v3 == 0, "Has IDO");
        {
            UserInfo storage user = users[account];
            if (!user.isExist) {
                if (!users[refer].isExist) {
                    users[refer].isExist = true;
                    userTotal++;
                    userAdds[userTotal] = refer;
                }
                user.isExist = true;
                userTotal++;
                userAdds[userTotal] = account;
                user.refer = refer;
                userInviteTotals[refer]++;
                userInvites[refer][userInviteTotals[refer]] = account;
                emit BindRefer(account, refer);
            } else {
                updateUser(account);
                if (user.refer == address(0) && users[refer].isExist) {
                    user.refer = refer;
                    userInviteTotals[refer]++;
                    userInvites[refer][userInviteTotals[refer]] = account;
                    emit BindRefer(account, refer);
                }
            }
        }
        _USDT.transferFrom(account, _stakeWallet, _stakeAmounts[index]);
        updateUser(account);
        stakeTotal++;
        stakes[stakeTotal] = StakeInfo({
            isValid: true,
            index: stakeTotal,
            userIndex: userStakes[account] + 1,
            amount: _stakeAmounts[index],
            rate: _stakeRates[index],
            startTime: block.timestamp,
            lastTime: block.timestamp,
            cancelTime: 0,
            reward: 0,
            owner: account
        });
        userStakes[account]++;
        userStakeIndex[account][userStakes[account]] = stakeTotal;
        {
            RewardInfo storage info = rewards[account];
            if (index == 0) {
                info.v1 = 1;
                info.v1Debt = (info.v1 * _v1PerReward) / 1e12;
                _v1Total++;
            } else if (index == 1) {
                info.v2 = 1;
                info.v2Debt = (info.v2 * _v2PerReward) / 1e12;
                _v2Total++;
            } else if (index == 2) {
                info.v3 = 1;
                info.v3Debt = (info.v3 * _v3PerReward) / 1e12;
                _v3Total++;
            }
            emit BalanceChange(
                account,
                1,
                index,
                _stakeAmounts[index],
                users[account].rewardTotal
            );
        }
        _totalIDO += _stakeAmounts[index];
        _sendInviteReward(account, _stakeAmounts[index]);
    }
    function claimInvite() public {
        address account = msg.sender;
        require(users[account].isExist, "User Not Exist");
        updateUser(account);
        UserInfo storage user = users[account];
        uint amount = user.balanceInvite;
        if (amount > 0) {
            user.balanceInvite = 0;
            _USDT.transfer(account, amount);
            emit BalanceChange(
                account,
                2,
                amount,
                user.balanceInvite,
                user.rewardInviteUSDT
            );
            _totalWithdrawUSDT += amount;
        }
    }
    function claimRelease() public {
        address account = msg.sender;
        require(!isBlackList[account], "Invalid address");
        require(users[account].isExist, "User Not Exist");
        updateUser(account);
        UserInfo storage user = users[account];
        uint amount = user.balanceUSDT;
        if (amount == 0) {
            return;
        }
        user.balanceUSDT = 0;
        _USDT.transfer(account, amount);
        emit BalanceChange(
            account,
            3,
            amount,
            user.balanceUSDT,
            user.rewardTotalUSDT
        );
        _totalWithdrawUSDT += amount;
    }
    function claimReward() public {
        address account = msg.sender;
        require(!isBlackList[account], "Invalid address");
        require(users[account].isExist, "User Not Exist");
        updateUser(account);
        require(users[account].balance >= _minWithdraw, "Lower Min Withdraw");
        UserInfo storage user = users[account];
        uint amount = user.balance;
        if (amount == 0) {
            return;
        }
        user.balance = 0;
        uint fee = (amount * _feeWithdraw) / 10000;
        if (fee > 0) _USDT.transfer(_feeTo, fee);
        _UN.transfer(account, amount - fee);
        emit BalanceChange(account, 4, amount, user.balance, user.rewardTotal);
        _totalWithdraw += amount;
    }
    function updateUser(address account) public {
        require(users[account].isExist, "User Not Exist");
        uint256 total = userStakes[account];
        uint256 rewardTotal;
        for (uint256 i = 0; i < total; i++) {
            uint256 index = userStakeIndex[account][i + 1];
            if (stakes[index].isValid && stakes[index].owner == account) {
                StakeInfo storage stake = stakes[index];
                uint256 timestamp = block.timestamp - stake.lastTime;
                uint256 reward = (stake.rate * stake.amount * timestamp) /
                    (10000 * _dayTimes);
                if (stake.amount <= stake.reward) {
                    stake.isValid = false;
                } else {
                    if (reward > stake.amount - stake.reward) {
                        reward = stake.amount - stake.reward;
                        stake.isValid = false;
                    }
                    rewardTotal += reward;
                    stake.lastTime = block.timestamp;
                    stake.reward += reward;
                }
            }
        }
        if (rewardTotal > 0) {
            users[account].balanceUSDT += rewardTotal;
            users[account].rewardTotalUSDT += rewardTotal;
            _totalRelease += rewardTotal;
            emit BalanceChange(
                account,
                5,
                rewardTotal,
                users[account].balanceUSDT,
                users[account].rewardTotalUSDT
            );
        }
        rewardTotal = 0;
        RewardInfo storage info = rewards[account];
        if (info.v1 > 0) {
            uint reward = (info.v1 * _v1PerReward) / 1e12 - info.v1Debt;
            info.v1Reward + reward;
            info.v1Debt = (info.v1 * _v1PerReward) / 1e12;
            rewardTotal += reward;
        }
        if (info.v2 > 0) {
            uint reward = (info.v2 * _v2PerReward) / 1e12 - info.v2Debt;
            info.v2Reward + reward;
            info.v2Debt = (info.v2 * _v2PerReward) / 1e12;
            rewardTotal += reward;
        }
        if (info.v3 > 0) {
            uint reward = (info.v3 * _v3PerReward) / 1e12 - info.v3Debt;
            info.v3Reward + reward;
            info.v3Debt = (info.v3 * _v3PerReward) / 1e12;
            rewardTotal += reward;
        }
        if (rewardTotal > 0) {
            users[account].balance += rewardTotal;
            users[account].rewardTotal += rewardTotal;
            _totalReward += rewardTotal;
            emit BalanceChange(
                account,
                6,
                rewardTotal,
                users[account].balance,
                users[account].rewardTotal
            );
        }
    }
    function sendReward(uint amount) public {
        if (_v1Total > 0) {
            _v1PerReward += ((amount / 6) * 1e12) / _v1Total;
        } else _v1PerReward += ((amount / 6) * 1e12);
        if (_v2Total > 0) {
            _v2PerReward += ((amount / 3) * 1e12) / _v2Total;
        } else _v2PerReward += ((amount / 3) * 1e12);
        if (_v3Total > 0) {
            _v3PerReward += ((amount / 2) * 1e12) / _v3Total;
        } else _v3PerReward += ((amount / 2) * 1e12);
        emit BalanceChange(msg.sender, 7, amount, 0, 0);
    }
    function _sendInviteReward(address account, uint amount) private {
        address refer = users[account].refer;
        uint rewardTotal;
        for (uint i = 0; i < 2; i++) {
            if (refer == address(0)) break;
            UserInfo storage parent = users[refer];
            if (parent.isExist) {
                uint reward = (amount * _inviteRates[i]) / 10000;
                parent.balanceInvite += reward;
                parent.rewardInviteUSDT += reward;
                rewardTotal += reward;
                emit BalanceChange(
                    account,
                    6,
                    reward,
                    users[refer].balanceInvite,
                    users[refer].rewardInviteUSDT
                );
            }
            refer = parent.refer;
        }
        _totalInvite += rewardTotal;
    }
}