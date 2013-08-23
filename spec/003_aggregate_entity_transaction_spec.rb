describe UnitOfWork::Transaction do
  before(:all) do
    class UnitOfWork::Transaction
      # exposed ONLY for testing purposes
      def tracked_objects
        @object_tracker
      end
    end
    @transaction = UnitOfWork::Transaction.new
  end

  it 'creates a new company in the database and retrieves it correctly' do
    company1_h = {
        name: 'Abstra.cc S.A',
        local_offices: [
            {
                description: 'branch1',
                addresses: [{description: 'addr1'}]
            }
        ]
    }

    a_company = Company.new(company1_h)
    @transaction.register_new(a_company)

    a_company.make_local_office({
                            description: 'branch2',
                            addresses: [{description: 'addr2.1'}]
                        })
    
    a_company.class.should eq(Company)
    a_company.name.should eq('Abstra.cc S.A')

    a_company.local_offices.size.should eq(2)

    a_company.local_offices[0].class.should eq(LocalOffice)
    a_company.local_offices[0].description.should eq('branch1')
    a_company.local_offices[0].addresses.size.should eq(1)
    a_company.local_offices[0].addresses[0].description.should eq('addr1')

    a_company.local_offices[1].description.should eq('branch2')
    a_company.local_offices[1].addresses[0].class.should eq(Address)
    a_company.local_offices[1].addresses[0].description.should eq('addr2.1')

    expect {a_company.local_offices[1].create}.to raise_error(RuntimeError)
    expect {a_company.local_offices[1].addresses[0].create}.to raise_error(RuntimeError)
    #expect {a_company.create}.to raise_error(RuntimeError) ???

    @transaction.commit

    abstra =  Company.fetch_by_id(1)

    abstra.class.should eq(Company)
    abstra.name.should eq('Abstra.cc S.A')
    abstra.id.should eq(1)

    abstra.local_offices.size.should eq(2)

    abstra.local_offices[0].class.should eq(LocalOffice)
    abstra.local_offices[0].description.should eq('branch1')
    abstra.local_offices[0].addresses.size.should eq(1)
    abstra.local_offices[0].addresses[0].description.should eq('addr1')

    abstra.local_offices[1].description.should eq('branch2')
    abstra.local_offices[1].addresses[0].class.should eq(Address)
    abstra.local_offices[1].addresses[0].description.should eq('addr2.1')

    company2_h = {
        name: 'Smarty Pants, Inc.',
        local_offices: [
            {
                description: 'foo del 1',
                addresses: [{description: 'foo dir 1'},
                              {description: 'foo dir 2'}]
            }
        ]
    }

    b_company = Company.new()
    b_company.make(company2_h)
    @transaction.register_new(b_company)

    @transaction.commit

    smarty_pants =  Company.fetch_by_id(2)

    smarty_pants.name.should eq('Smarty Pants, Inc.')
    smarty_pants.id.should eq(2)

    smarty_pants.local_offices.size.should eq(1)

    smarty_pants.local_offices[0].description.should eq('foo del 1')
    smarty_pants.local_offices[0].addresses.size.should eq(2)
    smarty_pants.local_offices[0].addresses[0].description.should eq('foo dir 1')
    smarty_pants.local_offices[0].addresses[1].description.should eq('foo dir 2')


    Company.fetch_all.size.should eq(2)

  end

end