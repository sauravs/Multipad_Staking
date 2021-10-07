

// SPDX-License-Identifier: MIT

 pragma solidity 0.8.7;


interface IERC20{

function name() external view returns ( string memory);
function symbol() external view returns (string memory);
function decimals() external view returns (uint8);
function totalSupply() external view returns (uint256);
function balanceOf(address _owner) external view returns (uint256 balance);
function transfer(address _to, uint256 _value) external returns (bool success);
function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
function approve(address _spender, uint256 _value) external returns (bool success);
function allowance(address _owner, address _spender) external view returns (uint256 remaining);

}



   /**
      
 * @title Multipad Staking Contract
 * 
 * @author Saurav Shekhar
 *
 * This is the staking pool contract for Multipad ERC20 Token Holders which will provide annual Yield/Interest of 20% of total MPAD Staked in the form
 * of extra MPAD tokens 
 * 
 */
    


     contract MultipadStaking {
         
         
         
  //////////////////////////////////////////////////////////////////////////////STORAGE VARIABLES DECLERATIONS//////////////////////////////////////////////////////////////////////////////////////////////////////
  
      
       /**
      
       *  Variable created to pause this staking pool by Admin in case of emeregency or when MARKETING&ECOSYTEM funds runs out of balance to 
       *  distribute the staking reward further
      
      
      */
      
      bool STOP_STAKING_POOL ;  
    
      
      address public constant MARKETING_ECOSYSTEM_WALLET_ADDRESS = 0x7cC26960D2A47c659A8DBeCEb0937148b0026fD6 ; 
      address public constant ADMIN_ADDRESS = 0x819de8bA8b172a6063923EB1b003fA9487773465 ; 
      
      
    
      /**
      
       *  Annual APY for staking MPAD is 20 % of the staked amount of MPAD Tokens.
       *  Therefore , per seconds reward will be 0.00000000635 %
      
      
      */
    
      uint public constant STAKING_PERSEC_REWARD = 635;                                 
      uint public constant STAKING_PERSEC_REWARD_RATIO = 100000000000 ;      // 0.00000000635
      
       
       /**
      
       *  Instant Unstaking Withdrawl of the Tokens is allowed.
       *  However, an investor has to pay penality of 10% of "Total Unstaking Amount" in the form of Multipad Tokens
       *  which will be later deposited to MPAD Marketing Funds
       *  Variable : totalAccumulatedMPADTokenPenalityAmount : Total Penality Fee Accumulated so far which can only be claimed by Admin
      */
      
      uint public constant INSTANT_WITHDRAWAL_PENALTY = 10 ;
      uint public constant INSTANT_WITHDRAWAL_PENALTY_RATIO = 100;
      uint public totalAccumulatedMPADTokenPenalityAmount ;
    
    //   mapping(address => uint256) public balanceOf;
    //   uint public marketingEcosystemReserveTokenBalance = balanceOf[address(this)];
      
      /**
      
       *  Variables :  stakedTokenWithdrawalTime ,unstakeTimerStart ,claimUnstakedToken ,isPreviousNormalUnstakingActive
       *  Related to Unstaking Functionality
       *  In Normal Mode ,when an investor unstake their tokens ,they will be  eligible to claim their unstaking amount to their respective 
          wallets only after 7 days .
       *  In this period defined by state variable 'unstakeTimerStart',however, investors are not allowed via 'isPreviousNormalUnstakingActive' variable 
          to "Unstake" again , until they claim their previous "Unstaking" amount.
         
      */
      
      uint public stakedTokenWithdrawalTime = 5 minutes;
      mapping(address => uint) internal unstakeTimerStart;
      mapping (address => uint256) public claimUnstakedToken ;
      mapping (address => bool) public isPreviousNormalUnstakingActive ;


       
    
      mapping(address => Stake) public stakers;                   // Mapping of each stakers's wallet address to "Stake" struct.             
    
      uint256 public totalMultipadStakedByAllAddresses ;           // Total Amount of Multipad Token currently Staked by all stakers/investors
    
      uint256  public stakersLength ;                              // Total number of stakers/investors currently has staking in this pool 

    
    
    mapping(address => bool) public hasStaked;                    // Stores information related to if a particular wallet address(investor) has 
                                                                  // currently staking or perviously staked or not
    
    
   
     
    
        
IERC20 multipadTokenInstance ;                                    // Instance of Multipad ERC20 Tokens 
IERC20 marketingAndEcosystemDistributionContract ;                // Instance of marketingAndEcosystemDistributionContract ERC20 Tokens 



     
 //////////////////////////////////////////////////////////////////////////////EVENT DECLERATION//////////////////////////////////////////////////////////////////////////////////////////////////////
    
      event Staked(address indexed user, uint256 amount);

      event UnStaked(address indexed _from, uint _value);
      
      
      
///////////////////////////////////////////////////////////////////////////Constructor Function///////////////////////////////////////////////////////////////////////////////////////////////////

  
  /**
     * Instantiate this pool contract with passing the address of Multipad ERC20 token address
     * Which makes sure , only staking of MPAD allowed
     * @param _multipadtokenaddress                          address of Multipad ERC20 Token
     */
  
  
  
  constructor(address _multipadtokenaddress )  {
      
    multipadTokenInstance = IERC20(_multipadtokenaddress);
  
    

      
  }
  
  
  //////////////////////////////////////////////////////////////////////////////////////Modifier Definitations////////////////////////////////////////////////////////////////////////////////////////////

  
   /*
     * Throws if the sender is not an Admin
   */
    
    modifier onlyAdmin {
        require (msg.sender == ADMIN_ADDRESS , 'Only Admin can has acess to this function');
       
        _;
        
    }
    
    
    
   /*
     * Throws if the sender is not a staker which has never been staked before in this pool
   */
    
    modifier currentlyStaked {
        require (hasStaked [msg.sender] == true , 'Only staked user has right to execute this function');
        _;
        
    }
    

      /*
        * Throws if the sender is not a owner of Marketing and Ecosystem pool of MPAD Tokens
      */
    

    
    modifier onlyMarketingEcosystemAdmin {
        
        
        require(msg.sender == MARKETING_ECOSYSTEM_WALLET_ADDRESS , 'Only Owner of Marketing Ecosystem can claim this penality MPAD Tokens');
        
        _;
    }
    
    
  
  //////////////////////////////////////////////////////////////////////////////DEFINING STRUCTS OF THE STAKE DATA///////////////////////////////////////////////////////////////////////////////////////////////////
      
       /*
        * struct 'Stake' define the data structure of each 'Stake'
      */
      
      
    struct Stake {
        
        address user;                         // wallet address of the user/staker/investor
        uint256 amount;                       //total amount of tokens currently the user has staked
        uint256 since;                        // time elasped since the user has last staked or unstaked
        uint256 claimable;                    // It provides information about how big of a reward is currently available to claim
       
        
    }

  //////////////////////////////////////////////////////////////////////////////////////Staking Function//////////////////////////////////////////////////////////////////////////////////////////////////
    
    /**
     * 'stakeTokens' function allows any users to stake their MPAD token in this staking pool contract
     *  An user is allowed to stake any amount of MPAD tokens as long as it is greator than zero and pool status is 'ACTIVE'
     * 
     * @param _amount                     Amount of Tokens an user want to stake
     */
    
    
function stakeTokens(uint256 _amount) public  {
    
       
       require( _amount > 0 , 'Staking amount should be greater than zero');
       
       require(STOP_STAKING_POOL == false ,'You cannot stake as Pool has been made Inactive by the Admin.Please contact Admin for enquiry') ;
       
       multipadTokenInstance.transferFrom(msg.sender, address(this), _amount);
       
       totalMultipadStakedByAllAddresses = totalMultipadStakedByAllAddresses + _amount;
       
       
       if (hasStaked[msg.sender] == false)
       
       {
           stakers[msg.sender] = Stake(msg.sender, _amount, block.timestamp, 0 );
           
           hasStaked[msg.sender] = true;
           
           stakersLength = stakersLength + 1;
       }
       
       else
       
       {
           uint256 reward = _calculateReward(stakers[msg.sender]);
          
           uint256 totalAmount = stakers[msg.sender].amount + _amount;
           
           uint256 totalReward = stakers[msg.sender].claimable + reward ;
           
           stakers[msg.sender] = Stake(msg.sender,totalAmount, block.timestamp , totalReward );
       }
      

         emit Staked(msg.sender, _amount);
         

    }
    
    
      //////////////////////////////////////////////////////////////////////////////////////Reward Generation Function //////////////////////////////////////////////////////////////////////////////////////////////////
       
       
       /**
         * '_calculateReward' function 
         *  
         * 
         *   To calulate Reward ,pass the instance of Stake of a particular staker              
        */
    
    
    
    function _calculateReward(Stake memory ) internal returns(uint256)
    
    
    {
           
        uint rewardAccuredTillCurrentTimestamp = block.timestamp - stakers[msg.sender].since ;
        
        return stakers[msg.sender].claimable =  (rewardAccuredTillCurrentTimestamp * stakers[msg.sender].amount * STAKING_PERSEC_REWARD)/STAKING_PERSEC_REWARD_RATIO ; 
    
                          
    }

    
    
    //////////////////////////////////////////////////////////////////////////////////////Unstaking the Multipad Tokens Function //////////////////////////////////////////////////////////////////////////////////////////////////
    
    
    
         /**
         * 'unstakeTokensImmediately' function 
         *  Via this function an user can unstake and withdraw its  unstake token into his/her wallet immediately
         *  However ,he/she has to pay penality amount of 10 % out of total Unstaking Token Amount in the
         *  form of MPAD tokens.
         *  @param _amount              Amount of Tokens an user want to unstake from his Total Staking Amount       
        */

    
    // Unstaking Tokens Immediately (Withdraw)   
    
    function unstakeTokensImmediately(uint _amount) public currentlyStaked {
        
        
        
        // Fetch staking balance
        uint256 balance = stakers[msg.sender].amount;
  

        // Require amount greater than 0
        
        require((balance >= _amount)  && (_amount > 0), "staking balance cannot be 0 ");
        
        
        // Penality Amount (10% of the staked tokens)
        
        
         uint penalityAmount = (_amount * INSTANT_WITHDRAWAL_PENALTY)/INSTANT_WITHDRAWAL_PENALTY_RATIO ;
         
         totalAccumulatedMPADTokenPenalityAmount = penalityAmount + totalAccumulatedMPADTokenPenalityAmount ;
        
        
        // Charge 10% Penalty for Instant Withdrawal os Staked Token 
        
         uint256 actualAmountToBeTransferred = _amount - penalityAmount ;

        // Transfer  Mutipad  tokens  back to its owner from this Staking contract
        
       multipadTokenInstance .transfer(msg.sender, actualAmountToBeTransferred);
       
       totalMultipadStakedByAllAddresses = totalMultipadStakedByAllAddresses - _amount ;
      
           uint256 reward = _calculateReward(stakers[msg.sender]);
           
           uint256 totalAmount = balance - _amount ;
           
           uint256 totalReward = stakers[msg.sender].claimable + reward;
           
           stakers[msg.sender] = Stake(msg.sender, totalAmount, block.timestamp, totalReward );

 
         emit UnStaked(msg.sender, _amount);
    } 
    
    
   

       /**
         * 'unstakeTokensNormally' function 
         *  Via this function an user can unstake its staked tokens , but only able to withdraw its  unstake token into his/her wallet after seven
         *  days.Once unstaking is done ,he would be able to withdraw into his wallet once 7 days has been passed from the his time of the
         *  Unstaking. He can withdraw it by using 'claimUnstakedTokens()' function

         * @param _amount                                             Amount of Tokens an user want to unstake from his Total Staking Amount       
        */




    
    
    function unstakeTokensNormally (uint _amount) public currentlyStaked {
        

        
    require( isPreviousNormalUnstakingActive[msg.sender] == false,'Your previous Unstaking Period is currently active.Wait for its expiration period and claim your Unstaking MPAD token first,You cannot unstake again in Normal Mode.');
        
        // Fetch staking balance
        uint256 balance = stakers[msg.sender].amount;


        // Require amount greater than 0
        
        require((balance >= _amount)  && (_amount > 0)  , "staking balance cannot be 0 ");

        // Transfer  Mutipad  tokens  back to its owner from this Stkaing 
        
        
        // need to implement the logic in such a way that ater 7 days balance automatically get transered to this account
        
          unstakeTimerStart[msg.sender] = block.timestamp;
          isPreviousNormalUnstakingActive[msg.sender] = true ;
                  

              
          claimUnstakedToken[msg.sender] = _amount ;
        
           uint256 reward = _calculateReward(stakers[msg.sender]);
           
           uint256 totalAmount = balance - _amount ;
           
           uint256 totalReward = stakers[msg.sender].claimable + reward;
           
           stakers[msg.sender] = Stake(msg.sender, totalAmount, block.timestamp, totalReward );

 
         emit UnStaked(msg.sender, _amount);
    } 
    

    
    ///////////////////////////////////////////////////////////////////////////////////////// CLAIM  UNSTKAED TOKENS AFTER SEVEN DAYS OF UNSTAKING /////////////////////////////////////////////////////////////////////////////////////////////////

    
      /**
         * 'claimUnstakedTokens()' function 
         *  Only those users who has/had successfully executed unstakeTokensNormally() function ,means Unstaked its staked token
         *  in Normal Mode,can use this function after seven days to withdraw its "Unstaking" amount into his wallet
        */


    
      function claimUnstakedTokens () external  {
          
           require(isPreviousNormalUnstakingActive[msg.sender] == true, 'You are not eligible to claim your Unstaked Tokens');
           require((block.timestamp  > (unstakeTimerStart[msg.sender] + stakedTokenWithdrawalTime )) , 'Seven Days Since You Unstaked Your Tokens havent been passed yet');
           
           multipadTokenInstance.transfer(msg.sender,  claimUnstakedToken[msg.sender]);
           
           totalMultipadStakedByAllAddresses = totalMultipadStakedByAllAddresses - claimUnstakedToken[msg.sender] ;
           
            unstakeTimerStart[msg.sender] = 0 ;
            
            claimUnstakedToken[msg.sender] = 0 ;
           
           isPreviousNormalUnstakingActive[msg.sender] = false ;
           
        
          
      }
      
    
    ///////////////////////////////////////////////////////////////////////////////////////// CLAIM YOUR REWARDED MPAD TOKENS /////////////////////////////////////////////////////////////////////////////////////////////////

       
          
      /**
         * 'claimAccumulatedRewardTokens ()' function 
         *  Function implmented to claim the reward accumulated for an eligible specific user/wallet address.
         * 
        */

      function claimAccumulatedRewardTokens () external currentlyStaked  {
   
     
          uint  timeElasped = block.timestamp - stakers[msg.sender].since ;
         
          uint reward =  (timeElasped * stakers[msg.sender].amount * STAKING_PERSEC_REWARD)/STAKING_PERSEC_REWARD_RATIO ; 
         
          uint totalreward = stakers[msg.sender].claimable + reward ;
         
         multipadTokenInstance .transferFrom(MARKETING_ECOSYSTEM_WALLET_ADDRESS , address(this), totalreward);   // marketingAndEcosystemDistributionContract approve this Staking contract address to execute this function successfully
         multipadTokenInstance.transfer( msg.sender, totalreward);
         
         stakers[msg.sender].claimable = 0 ;
         
         stakers[msg.sender] = Stake(msg.sender, stakers[msg.sender].amount, block.timestamp, 0 );
         
      }
      
      
///////////////////////////////////////////////////////////////////////////////////////// GET CURRENT ACCUMULATED REWARD FOR AN USER /////////////////////////////////////////////////////////////////////////////////////////////////


     
       function getAccumulatedExpectedRewardForAnUser (address _addr) public view currentlyStaked returns(uint) {
           
           
        uint currenttimeElasped = block.timestamp - stakers[_addr].since ;
                     
        uint currentAccumulatedExpectedreward  = (currenttimeElasped * stakers[msg.sender].amount * STAKING_PERSEC_REWARD)/STAKING_PERSEC_REWARD_RATIO ; 
                
        uint totalreward = stakers[msg.sender].claimable + currentAccumulatedExpectedreward ;
           
          return totalreward ;
           
       }




///////////////////////////////////////////////////////////////////////////////////////// ONLY ADMIN RELATED FUNCTION /////////////////////////////////////////////////////////////////////////////////////////////////

    
     /**
         * 'claimPenalityMpadTokens ()' function 
         *  Function implmented to claim and transfer the Penality tokens accumulated  by the this pooling contract  
         *  to 'Marketing and Ecosystem' Wallet Address.
         *  This function can only be  executed by the Admin. 
        */

    
    function claimPenalityMpadTokens () onlyMarketingEcosystemAdmin external {
        
        require(totalAccumulatedMPADTokenPenalityAmount > 0 ,'There is No penality tokens availble to claimed by MPAD Marketing Ecosytem');
        
        multipadTokenInstance.transfer( MARKETING_ECOSYSTEM_WALLET_ADDRESS , totalAccumulatedMPADTokenPenalityAmount);
        
        totalAccumulatedMPADTokenPenalityAmount = 0 ;
        
     
    }
    
    
    
    
 /////////////////////////////////////////////////////////////////////////////////////////PAUSE/RESTART STAKING /////////////////////////////////////////////////////////////////////////////////////////////////

    
         /**
         * 'stopStakingPool()' function 
         *  Function implmented in case Admin wants to pause/stop this staking pool contract
         *  to further staking 
         *  Activation of this 'STOP_STAKING_POOL' == true ,will result in probhition to stake further.
        */


        function stopStakingPool() public onlyAdmin {
        
        require(STOP_STAKING_POOL == false , ' Staking has already been stoped by Admin') ;
        
        STOP_STAKING_POOL = true ;
        
    }

       
       
       
         /**
         * 'restartStaking()' function 
         *  Function implmented  in case Admin wants to restart this staking pool contract.
        */

       
       
        function restartStaking() public onlyAdmin {
        
        require(STOP_STAKING_POOL == true , 'Staking is already active') ;
        
        STOP_STAKING_POOL = false ;
        
    }
       
      
       
        
    }

    
    
    

       

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
