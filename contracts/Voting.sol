// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Voting {

    address public admin;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin allowed");
        _;
    }

    struct Candidate {
        string name;
        uint voteCount;
    }

    struct Election {
        string name;
        uint startTime;
        uint endTime;
        uint candidateCount;
        mapping(uint => Candidate) candidates;
        mapping(bytes32 => bool) hasVoted; // PRN-based voting
    }

    uint public electionCount;
    mapping(uint => Election) private elections;

    // ===== PRN SYSTEM =====

    mapping(bytes32 => bool) public validPRN;         // Whitelisted PRNs
    mapping(address => bytes32) public registeredPRN; // Wallet → PRN //this prevents one wallet -> multiple PRNs
    mapping(bytes32 => bool) public prnUsed; // this prevents one PRN -> multiple wallets
    //Anyone who knows a PRN can claim and control it.

    // ===== ADMIN FUNCTIONS =====

    function createElection(
        string memory _name,
        uint _startTime,
        uint _endTime
    ) public onlyAdmin {

        require(_startTime < _endTime, "Invalid time range");

        elections[electionCount].name = _name;
        elections[electionCount].startTime = _startTime;
        elections[electionCount].endTime = _endTime;

        electionCount++;
    }

    function addCandidate(
        uint _electionId,
        string memory _name
    ) public onlyAdmin {

        require(_electionId < electionCount, "Election not found");

        Election storage e = elections[_electionId];

        e.candidates[e.candidateCount] = Candidate(_name, 0);
        e.candidateCount++;
    }

    function whitelistPRN(bytes32 _hashedPRN) public onlyAdmin {
        validPRN[_hashedPRN] = true;
    }
    function whitelistMultiplePRNs(bytes32[] memory _hashedPRNs) public onlyAdmin {
    for(uint i = 0; i < _hashedPRNs.length; i++){
        validPRN[_hashedPRNs[i]] = true;
    }
}

    // ===== STUDENT FUNCTIONS =====

    function register(bytes32 _hashedPRN) public {
        
        require(validPRN[_hashedPRN], "PRN not valid");
        require(registeredPRN[msg.sender] == 0, "Wallet already registered");
        require(!prnUsed[_hashedPRN], "PRN already used");

        registeredPRN[msg.sender] = _hashedPRN; //msg.sender is the wallet address (more precisely, the caller’s address).
        prnUsed[_hashedPRN] = true;
    }

    function vote(
        uint _electionId,
        uint _candidateId
    ) public {

        require(_electionId < electionCount, "Election not found");

        Election storage e = elections[_electionId];

        require(
            block.timestamp >= e.startTime &&
            block.timestamp <= e.endTime,
            "Election not active"
        );

        bytes32 prn = registeredPRN[msg.sender];

        require(prn != 0, "Not registered");
        require(!e.hasVoted[prn], "Already voted");
        require(_candidateId < e.candidateCount, "Invalid candidate");

        e.candidates[_candidateId].voteCount++;
        e.hasVoted[prn] = true;
    }

    // ===== VIEW FUNCTIONS =====

    function getElectionCount() public view returns(uint) {
        return electionCount;
    }

    function getElection(uint _electionId)
        public
        view
        returns(string memory, uint, uint)
    {
        Election storage e = elections[_electionId];
        return (e.name, e.startTime, e.endTime);
    }

    function getCandidateCount(uint _electionId)
        public
        view
        returns(uint)
    {
        return elections[_electionId].candidateCount;
    }

    function getCandidate(uint _electionId, uint _candidateId)
        public
        view
        returns(string memory, uint)
    {
        Candidate storage c = elections[_electionId].candidates[_candidateId];
        return (c.name, c.voteCount);
    }

    function hasPRNVoted(uint _electionId, bytes32 _hashedPRN)
        public
        view
        returns(bool)
    {
        return elections[_electionId].hasVoted[_hashedPRN];
    }
}