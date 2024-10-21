// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TokenTracking {
    address public deployer;
    address public tokenAddress;
    address public stock;
    address public pcap;
    bool public endState = false;
    uint256 public totalPoints;
    uint256 public totalStockRaised;

    uint256 public constant MAX_ID = 19;
    uint256 public constant PCAP_AMOUNT = 25;  // Representing 0.25 * 100
    
    mapping(uint256 => uint256) public idTotalAmount; // Tracks total amount brought by each ID
    mapping(address => uint256) public userPoints; // Tracks points for each user
    mapping(uint256 => uint256) public idPoints; // Tracks points for each ID

    event DepositMade(address indexed user, uint256 indexed id, uint256 amount);
    event PointsClaimed(address indexed user, uint256 reward1Amount, uint256 reward2Amount);
    event ContractEnded();

    constructor(address _tokenAddress) {
        deployer = msg.sender;
        tokenAddress = _tokenAddress;
    }

    modifier onlyDeployer() {
        require(msg.sender == deployer, "Only deployer can call this function.");
        _;
    }

    modifier notEnded() {
        require(!endState, "Deposits are not allowed after the contract has ended.");
        _;
    }

    // Deposit function for users to transfer tokens and gain points
    function Deposit(uint256 _id, uint256 _amount) external notEnded {
        require(_id >= 0 && _id <= MAX_ID, "Invalid ID, must be between 0 and 19.");
        require(_amount > 0, "Amount must be greater than zero.");

        // Transfer the token from the user to the contract
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), _amount), "Token transfer failed.");

        // Transfer the token from the contract to the deployer
        require(IERC20(tokenAddress).transfer(deployer, _amount), "Token transfer to deployer failed.");

        // Update tracking
        idTotalAmount[_id] += _amount;  // Track total amount for this ID
        totalPoints += _amount; // Track total amount deposited to the contract
        
        // Assume 1 point per token deposited
        uint256 pointsToAdd = _amount; 
        
        idPoints[_id] += pointsToAdd;             // ID gets points based on deposit amount
        userPoints[msg.sender] += pointsToAdd;    // User gets points based on deposit amount

        emit DepositMade(msg.sender, _id, _amount); // Emit Deposit event
    }

    // Function to end the deposit phase; only deployer can call this
    function End (address _pcap, address _stock) external onlyDeployer {
        require(endState == false, "Already ended");
        pcap = _pcap;
        stock = _stock;
        endState = true;
        totalStockRaised = IERC20(stock).balanceOf(address(this));
        emit ContractEnded(); // Emit End event
    }

    // Function for users to claim their rewards based on points
    function ClaimPoints() external {
        require(endState, "Rewards can only be claimed after the contract has ended.");
        uint256 points = userPoints[msg.sender];
        require(points > 0, "No points to claim.");

        // Calculate rewards (scaled by 100 to avoid decimals)
        uint256 pcapAmount = points * PCAP_AMOUNT / 100;
        uint256 stockAmount = points * totalStockRaised / totalPoints;

        // Reset user's points
        userPoints[msg.sender] = 0;

        // Transfer rewards
        require(IERC20(pcap).transfer(msg.sender, pcapAmount), "PCAP transfer failed.");
        require(IERC20(stock).transfer(msg.sender, stockAmount), "STOCK transfer failed.");

        emit PointsClaimed(msg.sender, pcapAmount, stockAmount); // Emit ClaimPoints event
    }

    // Function for users to check their stock based on points
    function RewardsToClaim() external view returns (uint256 [2] memory rewards) {
        uint256 points = userPoints[msg.sender];
        // Calculate rewards (scaled by 100 to avoid decimals)
        uint256 pcapAmount = points * PCAP_AMOUNT / 100;
        uint256 stockAmount = points * totalStockRaised / totalPoints;
        rewards = [pcapAmount, stockAmount];
        return rewards;
    }

}

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
