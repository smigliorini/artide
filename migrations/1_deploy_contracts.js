
// Truffle migration file.

const main = artifacts.require( "Agency" );
//const camp = artifacts.require( "Campaign" );

module.exports = function(deployer) {
    deployer.deploy(main);
    //deployer.deploy(camp);
}
