let provider;
let signer;
let contract;

const contractAddress = "0x2f02Ad5F8a426Fe7C27C4551aAE4895D1B9475a4";

const abi = [
  "function createElection(string,uint,uint)",
  "function getElectionCount() view returns(uint)",
  "function getElection(uint) view returns(string,uint,uint)",
  "function addCandidate(uint,string)",
  "function getCandidateCount(uint) view returns(uint)",
  "function getCandidate(uint,uint) view returns(string)"
];

async function connectWallet() {
  if (!window.ethereum) {
    alert("Install MetaMask");
    return;
  }

  provider = new ethers.BrowserProvider(window.ethereum);
  signer = await provider.getSigner();
  contract = new ethers.Contract(contractAddress, abi, signer);

  console.log("Wallet connected");
}

function toTimestamp(value){
  return Math.floor(new Date(value).getTime()/1000);
}

async function createElection(){

  if(!contract) return alert("Connect wallet");

  const name = document.getElementById("eName").value;
  const start = toTimestamp(document.getElementById("start").value);
  const end = toTimestamp(document.getElementById("end").value);

  const tx = await contract.createElection(name,start,end);
  await tx.wait();

  alert("Election created");
}

async function loadElections(){

  const count = await contract.getElectionCount();
  const select = document.getElementById("electionSelect");
  select.innerHTML="";

  for(let i=0;i<count;i++){
    const e = await contract.getElection(i);
    const opt=document.createElement("option");
    opt.value=i;
    opt.text=`${i} - ${e[0]}`;
    select.appendChild(opt);
  }
}

async function addCandidate(){

  const id=document.getElementById("electionSelect").value;
  const name=document.getElementById("candidate").value;

  const tx=await contract.addCandidate(id,name);
  await tx.wait();

  alert("Candidate added");
}