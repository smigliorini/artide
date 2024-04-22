const agency = artifacts.require("Agency");
const campaign = artifacts.require("Campaign");

contract("Contract tests", () => {

    let agencyContract = undefined;
    let accounts = undefined;

    const details1 = {
        id: 0,
        topic: "Topic1",
        promoter: "Promoter1",
        start: 0,
        end: 1,
        goal: 10000,
        currencyCode: 978,
        currencyScale: 2
    };

    const details2 = {
        id: 1,
        topic: "Topic2",
        promoter: "Promoter2",
        start: 0,
        end: 1,
        goal: 10000,
        currencyCode: 978,
        currencyScale: 2
    };

    const newDetails2 = {
        id: 1,
        topic: "Topic 2 new",
        promoter: "Promoter2",
        start: 0,
        end: 1,
        goal: 10000,
        currencyCode: 978,
        currencyScale: 2
    };


    const details3 = {
        id: 2,
        topic: "Topic3",
        promoter: "Promoter3",
        start: 0,
        end: 1,
        goal: 10000,
        currencyCode: 978,
        currencyScale: 2
    };

    const newDetails3 = {
        id: 2,
        topic: "TopicNew3",
        promoter: "PromoterNew3",
        start: 0,
        end: 1,
        goal: 17000,
        currencyCode: 978,
        currencyScale: 2
    };

    const newWrongDetails3 = {
        id: 2,
        topic: "Topic3",
        promoter: "Promoter3",
        start: 0,
        end: 1,
        goal: 10000,
        currencyCode: 978,
        currencyScale: 2
    };

    const donation = {
        id: 0,
        update: 0,
        when: 123,
        amount:  300,
        donorId: 10,
        donorCode: "10",
        donorName: "Donor Name",
        partId: 1,
        partName: "part name",
        partUnits: [1, 2]
    }

    const newWrongDonation = {
        id: 1,
        update: 0,
        when: 123,
        amount:  300,
        donorId: 10,
        donorCode: "10",
        donorName: "Donor Name",
        partId: 1,
        partName: "part name",
        partUnits: [1, 2]
    }

    const newDonation = {
        id: 0,
        update: 0,
        when: 123,
        amount:  300,
        donorId: 10,
        donorCode: "10",
        donorName: "Donor Name",
        partId: 1,
        partName: "part name",
        partUnits: [1, 2, 3]
    }

    // -----------------------------------------------------------------------------------------------------------------

    before("Agency deployment", async () => {
        agencyContract = await agency.deployed();
        assert(agencyContract, "agency contract was not deployed");

        accounts = await web3.eth.getAccounts();
    });

    // it() stands for individual test
    it("Agency initial counters", async () => {
            const campaigns = await agencyContract.countCampaigns();
            const total = campaigns.total.toNumber();
            const active = campaigns.active.toNumber();
            const archived = campaigns.archived.toNumber();
            assert.equal(total, 0, "no campaigns has been created right now");
            assert.equal(active, 0, "no active campaigns right now");
            assert.equal(archived, 0, "no archived campaigns right now");
        }
    );

    it("Campaigns creation", async () => {
        try {
            const campaigns = await agencyContract.selectActiveCampaigns(0, 1);
            assert.fail("exception has not been raised: no error in selecting unexisting campaigns");
        } catch (err) {
            assert.ok("exception has been raised: error in selecting unexisting campaigns")
        }

        const camp1 = await agencyContract.createCampaign(details1, {from: accounts[0]});
        const camp2 = await agencyContract.createCampaign(details2, {from: accounts[0]});

        try {
            const campaigns = await agencyContract.selectActiveCampaigns(0, 10);
            assert.ok("exception has not been raised while selecting campaigns");
        } catch (err) {
            assert.fail("exception has been raised while selecting campaigns")
        }

        const counters = await agencyContract.countCampaigns();
        const total = counters.total.toNumber();
        const active = counters.active.toNumber();
        const archived = counters.archived.toNumber();
        assert.equal(total, 2, "one campaign has been created right now");
        assert.equal(active, 2, "one active campaign right now");
        assert.equal(archived, 0, "no archived campaigns right now");

        try {
            const camp3 = await agencyContract.createCampaign(details3, {from: accounts[1]});
            assert.fail("exception has not been raised: campaign added without permissions")
        } catch (err) {
            assert.ok("exception has been raised: campaign cannot be added without permissions");
        }
    })

    it("Campaign archiving", async () => {
        const camp3 = await agencyContract.createCampaign(details3, {from: accounts[0]});

        const counters1 = await agencyContract.countCampaigns();
        const total1 = counters1.total.toNumber();
        const active1 = counters1.active.toNumber();
        const archived1 = counters1.archived.toNumber();
        assert.equal(total1, 3, "one campaign has been created right now");
        assert.equal(active1, 3, "one active campaign right now");
        assert.equal(archived1, 0, "no archived campaigns right now");

        try {
            await agencyContract.archiveCampaign(0, true, {from: accounts[0]});
            assert.ok("exception has not been raised while archiving campaign 0");

        } catch (err) {
            assert.include(err.message, "exception has been raised while archiving campaign 0")
        }

        const counters2 = await agencyContract.countCampaigns();
        const total2 = counters2.total.toNumber();
        const active2 = counters2.active.toNumber();
        const archived2 = counters2.archived.toNumber();
        assert.equal(total2, 3, "one campaign has been created right now");
        assert.equal(active2, 2, "one active campaign right now");
        assert.equal(archived2, 1, "no archived campaigns right now");
    })

    it("Campaign update", async () => {
        const campaigns = await agencyContract.selectActiveCampaigns(0, 3);
        //console.log( "NUMBER OF CAMPAIGNS " + campaigns.length );


        const c1 = await campaign.at(campaigns[1]);
        const b1 = await c1.isActive();
        assert.equal(b1, true, "campaign 1 is active");
        const a1 = await c1.isArchived();
        assert.equal(a1, false, "campaign 1 is not archived");
        const l1 = await c1.isLocked();
        assert.equal(l1, false, "campaign 1 is not locked");

        try {
            await c1.updateDetails(newDetails3, {from: accounts[0]});
            assert.ok("Campaign update successfully completed");
        } catch (err) {
            assert.include(err.message, "Campaign update has been failed")
        }

        try {
            c1.updateDetails(newWrongDetails3);
            assert.fail("Campaign update with wrong details: ID cannot be changed");
        } catch (err) {
            assert.ok("Campaign update correctly failed: ID cannot be changed");
        }
    })

    it("Donation registration", async() => {
        const campaigns = await agencyContract.selectActiveCampaigns(0, 2);
        const c = await campaign.at(campaigns[0]);

        try {
            await c.updateDetails(newDetails2, {from: accounts[0]});
            assert.ok("Campaign update succesfully done" );
        } catch (err) {
            assert.fail("Campaign update has been failed")
        }

        await c.registerDonation( donation );

        try {
            await c.updateDetails(newDetails2, {from: accounts[0]});
            assert.fail("Campaign update has not been failed" );
        } catch (err) {
            assert.ok("Campaign update has been failed")
        }
    })

    it("Donation update", async() => {
        const campaigns = await agencyContract.selectActiveCampaigns(0, 2);
        const c = await campaign.at(campaigns[0]);

        try {
            await c.updateDonation(newDonation, {from: accounts[0]});
            assert.ok("Donation update succesfully done" );
        } catch (err) {
            assert.include( err.message, "Donation update has been failed")
        }


        try {
            await c.updateDonation(newWrongDonation, {from: accounts[0]});
            assert.fail("Donation update has not been failed" );
        } catch (err) {
            assert.ok("Donation update has been failed")
        }
    })
});
