// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    }

    struct Election {
        string name;
        uint startTime;
        uint endTime;
        Candidate[] candidates;
    }

    Election[] public elections;

    // ======================
    // ELECTION FUNCTIONS
    // ======================

    function createElection(
        string memory _name,
        uint _startTime,
        uint _endTime
    ) public onlyAdmin {

        require(_endTime > _startTime, "Invalid time");

        elections.push();
        Election storage e = elections[elections.length - 1];

        e.name = _name;
        e.startTime = _startTime;
        e.endTime = _endTime;
    }

    function getElectionCount() public view returns (uint) {
        return elections.length;
    }

    function getElection(uint index)
        public
        view
        returns (string memory, uint, uint)
    {
        Election storage e = elections[index];
        return (e.name, e.startTime, e.endTime);
    }

    // ======================
    // CANDIDATE FUNCTIONS
    // ======================

    function addCandidate(uint electionId, string memory candidateName)
        public
        onlyAdmin
    {
        elections[electionId].candidates.push(
            Candidate(candidateName)
        );
    }

    function getCandidateCount(uint electionId)
        public
        view
        returns (uint)
    {
        return elections[electionId].candidates.length;
    }

    function getCandidate(uint electionId, uint candidateIndex)
        public
        view
        returns (string memory)
    {
        return elections[electionId].candidates[candidateIndex].name;
    }
}