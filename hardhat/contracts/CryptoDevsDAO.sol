// SPX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@oppenzeppelin/contracts/access/Ownable.sol";

contract CryptoDevsDAO is Ownable {
  interface  IFakeNFTMarketPlace {
    function getPrice() external view returns (uint256);

    function available(uint256 _tokenId) external view returns (bool);

    function purchase(uint256 _tokenId) external payable;
  }
  
  interface ICryptoDevsNFT { 
    function balanceOf(address owner) external view returns (uint256);

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
  }

  struct Proposal {
    uint256 nftTokenId;
    uint256 deadline;
    uint256 yesVotes;
    uint256 noVotes;
    bool executed;

    mapping(uint256 => bool) voters;
  }

  mapping(uint256 => Proposal) public proposals;

  uint256 public numProposals;

  IFakeNFTMarketPlace nftMarketPlace;
  ICryptoDevsNFT cryptoDevsNFT;

  constructor(address _nftMarketPlace, address _crypotDevsNFT) payable {
    nftMarketPlace = IFakeNFTMarketPlace(_nftMarketPlace);
    cryptoDevsNFT = ICryptoDevsNFT(_crypotDevsNFT);
  }

  modifier nftHolderOnly() {
    require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "Not a DAO member");
    _;
  }

  function createProposal(uint256 _nftTokenId) external nftHolderOnly returns (uint256) {
    require(nftMarketPlace.available(_nftTokenId), "NFT not for sale");
    Proposal storage proposal = proposals[numProposals];
    proposal.nftTokenId = _nftTokenId;
    proposal.deadline = block.timestamp + 5 minutes;

    numProposals++;

    return numProposals - 1;
  }

  modifier activeProposalOnly(uint256 proposalIndex) {
    require(proposal[proposalIndex].deadline > block.timestamp, "Deadline exceed");
    _;
  }

  enum Vote {
    Yes,
    No
  }

  function voteOnproposal(uint256 proposalIndex, Vote vote) external nftHolderOnly activeProposalOnly(proposalIndex) {
    Proposal storage proposal = proposals[proposalIndex];

    uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
    uint256 numVotes = 0;

    for(uint256 i = 0; i < voterNFTBalance; i++){
      uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
      if(proposal.voters[tokenId] == false){
        numVotes++;
        proposal.voters[tokenId] = true;
      }
    }
    require(numVotes > 0, "Already voted);

    if(vote == Vote.Yes){
      proposal.yesVotes += numVotes;
    } else {
      proposal.noVotes += numVotes;
    }
  }

  modifier inactiveProposalOnly(uint256 proposalIndex) {
    require(proposals[proposalIndex].deadline <= block.timestamp, "Deadline not exceeded");
    require(proposals[proposalIndex].executed == false, "Proposal already voted");
    _;
  }

  function executeProposal(uint256 proposalIndex) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
    if(proposal.yesVotes > proposal.noVotes) {
      uint256 nftPrice = nftMarketPlace.getPrice();
      require(address(this).balance >= nftPrice, "Not enough funds");
      nftMarketPlace.purchase{value: nftPrice}(proposal.nftTokenId);
    }
    proposal.executed = true;
  }

  function withdrawEther() external onlyOwner{
    uint256 amount = address(this).balance;
    require(amount > 0, "Nothing to withdraw, contract balance empty");
    payable(owner().transfer(amount));
  }

  receive() external payable{}
  fallback() external payable{}
}
