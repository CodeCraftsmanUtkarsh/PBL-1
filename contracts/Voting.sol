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

    // ======================
    // STRUCTS
    // ======================
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

        // 🔥 Aadhaar hash → voted?
        mapping(bytes32 => bool) hasVoted;
    }

    uint public electionCount;
    mapping(uint => Election) private elections;

    // ======================
    // 🔥 CORE STORAGE
    // ======================

    // electionId → aadhaarHash → whitelisted?
    mapping(uint => mapping(bytes32 => bool)) public validVoterId;

    // electionId → wallet → aadhaarHash
    mapping(uint => mapping(address => bytes32)) public registeredVoterId;

    // electionId → aadhaarHash → used?
    mapping(uint => mapping(bytes32 => bool)) public voterIdUsed;

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    function createElection(
        string memory _name,
        uint _startTime,
        uint _endTime
    ) public onlyAdmin {

        require(_startTime < _endTime, "Invalid time");

        Election storage e = elections[electionCount];

        e.name = _name;
        e.startTime = _startTime;
        e.endTime = _endTime;

        electionCount++;
    }

    function addCandidate(uint _electionId, string memory _name)
        public onlyAdmin
    {
        Election storage e = elections[_electionId];

        e.candidates[e.candidateCount] = Candidate(_name, 0);
        e.candidateCount++;
    }

    function whitelistMultipleVoterIds(
        uint _electionId,
        bytes32[] memory _ids
    ) public onlyAdmin {

        for (uint i = 0; i < _ids.length; i++) {
            validVoterId[_electionId][_ids[i]] = true;
        }
    }

    // ======================
    // USER FUNCTIONS
    // ======================

function register(uint _electionId, bytes32 _hashedId) public {

    require(msg.sender == admin, "Only backend can register");

    require(validVoterId[_electionId][_hashedId], "Not whitelisted");

    require(
        !voterIdUsed[_electionId][_hashedId],
        "Aadhaar already used"
    );

    // 🔥 store mapping (wallet must be passed now)
    revert("Use registerFromBackend");
}

// ✅ NEW FUNCTION
function registerFromBackend(
    uint _electionId,
    address user,
    bytes32 _hashedId
) public onlyAdmin {

    require(validVoterId[_electionId][_hashedId], "Not whitelisted");

    require(
        registeredVoterId[_electionId][user] == bytes32(0),
        "Already registered"
    );

    require(
        !voterIdUsed[_electionId][_hashedId],
        "Aadhaar already used"
    );

    registeredVoterId[_electionId][user] = _hashedId;
    voterIdUsed[_electionId][_hashedId] = true;
}

    function vote(uint _electionId, uint _candidateId) public {

        Election storage e = elections[_electionId];

        require(
            block.timestamp >= e.startTime &&
            block.timestamp <= e.endTime,
            "Election not active"
        );

        bytes32 voterId = registeredVoterId[_electionId][msg.sender];

        require(voterId != bytes32(0), "Not registered");
        require(!e.hasVoted[voterId], "Already voted");

        e.candidates[_candidateId].voteCount++;
        e.hasVoted[voterId] = true;
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    function hasAlreadyVoted(uint _electionId, address user)
        public view returns(bool)
    {
        bytes32 voterId = registeredVoterId[_electionId][user];

        if (voterId == bytes32(0)) return false;

        return elections[_electionId].hasVoted[voterId];
    }

    function isRegistered(uint _electionId, address user)
        public view returns(bool)
    {
        return registeredVoterId[_electionId][user] != bytes32(0);
    }

    function isWhitelisted(uint _electionId, bytes32 h)
        public view returns(bool)
    {
        return validVoterId[_electionId][h];
    }

    function getElectionCount() public view returns(uint){
        return electionCount;
    }

    function getElection(uint id)
        public view returns(string memory,uint,uint)
    {
        Election storage e = elections[id];
        return (e.name, e.startTime, e.endTime);
    }

    function getCandidateCount(uint id)
        public view returns(uint)
    {
        return elections[id].candidateCount;
    }

    function getCandidate(uint id,uint cid)
        public view returns(string memory,uint)
    {
        Candidate storage c = elections[id].candidates[cid];
        return (c.name, c.voteCount);
    }

    // ======================
    // 🔥 OPTIONAL (ADMIN TRANSFER)
    // ======================

    function transferAdmin(address newAdmin) public onlyAdmin {
        admin = newAdmin;
    }
}