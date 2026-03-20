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
        mapping(bytes32 => bool) hasVoted;
    }

    uint public electionCount;
    mapping(uint => Election) private elections;

    // ===== VOTER ID SYSTEM =====

    mapping(bytes32 => bool) public validVoterId;
    mapping(address => bytes32) public registeredVoterId;
    mapping(bytes32 => bool) public voterIdUsed;

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

    function whitelistVoterId(bytes32 _hashedId) public onlyAdmin {
        validVoterId[_hashedId] = true;
    }
    function whitelistMultipleVoterIds(bytes32[] memory _hashedIds) public onlyAdmin {
    for(uint i = 0; i < _hashedIds.length; i++){
        validVoterId[_hashedIds[i]] = true;
    }
}
    // ===== USER FUNCTIONS =====

    function register(bytes32 _hashedId) public {

        require(validVoterId[_hashedId], "Voter ID not valid");
        require(registeredVoterId[msg.sender] == 0, "Wallet already registered");
        require(!voterIdUsed[_hashedId], "Voter ID already used");

        registeredVoterId[msg.sender] = _hashedId;
        voterIdUsed[_hashedId] = true;
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

        bytes32 voterId = registeredVoterId[msg.sender];

        require(voterId != 0, "Not registered");
        require(!e.hasVoted[voterId], "Already voted");
        require(_candidateId < e.candidateCount, "Invalid candidate");

        e.candidates[_candidateId].voteCount++;
        e.hasVoted[voterId] = true;
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
}