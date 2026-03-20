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

    // ===== PER ELECTION VOTER SYSTEM =====

    mapping(uint => mapping(bytes32 => bool)) public validVoterId;
    mapping(uint => mapping(address => bytes32)) public registeredVoterId;
    mapping(uint => mapping(bytes32 => bool)) public voterIdUsed;

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

    function whitelistVoterId(uint _electionId, bytes32 _hashedId) public onlyAdmin {
        require(_electionId < electionCount, "Election not found");
        validVoterId[_electionId][_hashedId] = true;
    }

    function whitelistMultipleVoterIds(uint _electionId, bytes32[] memory _hashedIds) public onlyAdmin {
        require(_electionId < electionCount, "Election not found");

        for(uint i = 0; i < _hashedIds.length; i++){
            validVoterId[_electionId][_hashedIds[i]] = true;
        }
    }

    // ===== USER FUNCTIONS =====

    function register(uint _electionId, bytes32 _hashedId) public {

        require(_electionId < electionCount, "Election not found");
        require(validVoterId[_electionId][_hashedId], "Not whitelisted for this election");
        require(registeredVoterId[_electionId][msg.sender] == 0, "Already registered");
        require(!voterIdUsed[_electionId][_hashedId], "Voter ID already used");

        registeredVoterId[_electionId][msg.sender] = _hashedId;
        voterIdUsed[_electionId][_hashedId] = true;
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

        bytes32 voterId = registeredVoterId[_electionId][msg.sender];

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

    // ===== HELPER FUNCTIONS =====

    function isWhitelisted(uint _electionId, bytes32 _hashedId) public view returns(bool){
        return validVoterId[_electionId][_hashedId];
    }

    function isRegistered(uint _electionId, address user) public view returns(bool){
        return registeredVoterId[_electionId][user] != 0;
    }
}