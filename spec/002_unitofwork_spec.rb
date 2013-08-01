require 'lib/mapper'
require 'models/user'

describe UnitOfWork do
  before(:all) do
    insert_test_users

    class UnitOfWork
      # exposed ONLY for testing purposes
      def tracked_objects
        @object_tracker
      end
    end
    UnitOfWork.mapper = SequelMapper.new
    @uow = UnitOfWork.new
    @a_user = User.fetch_by_id(1)
  end

  it "has a unique identifier" do
    @uow.uuid.should =~ /^[0-9a-f]{32}$/
  end

  it "correctly registers itself with the Registry" do
    UnitOfWorkRegistry::Registry.instance[@uow.uuid.to_sym].should eq(@uow)
  end

  it "correctly registers an object with a UnitOfWork" do
    @uow.register_clean(@a_user)

    found_tracked_objects = @uow.tracked_objects.fetch_by_state(UnitOfWork::STATE_CLEAN)
    found_tracked_objects.size.should eq(1)
    found_tracked_objects.first.object.should eq(@a_user)

    u = @a_user.units_of_work
    u.length.should eq(1)
    found_uow = @a_user.units_of_work[0]
    found_uow.unit_of_work.should eq(@uow)
    found_uow.state.should eq(UnitOfWork::STATE_CLEAN)

    @b_user = User.fetch_by_id(2)
    @b_user.units_of_work.should be_empty
  end

  it "fetches a specific tracked object from the tracked object's class and its id" do
    @uow.fetch_object_by_id(@a_user.class, @a_user.id).object.should eq(@a_user)
    @uow.fetch_object_by_id(@a_user.class, 42).should be_nil

    User.fetch_from_unit_of_work(@uow.uuid, @a_user.id).object.should eq(@a_user)
    User.fetch_from_unit_of_work('c0ffeeb4b3', 42).should be_nil
  end

  it "correctly moves an object between states" do
    @a_user.name = 'Andrew'
    @uow.register_dirty(@a_user)

    @uow.tracked_objects.fetch_by_state(UnitOfWork::STATE_CLEAN).length.should eq(0)
    found_tracked_objects = @uow.tracked_objects.fetch_by_state(UnitOfWork::STATE_DIRTY)
    found_tracked_objects.size.should eq(1)
    found_tracked_objects.first.object.should eq(@a_user)

    found_uow = @a_user.units_of_work
    found_uow.size.should eq(1)
    found_uow[0].state.should eq(UnitOfWork::STATE_DIRTY)
  end

  it "correctly saves changes to dirty objects when calling commit" do
    @uow.commit
    @uow.valid.should eq(true)

    @uow.tracked_objects.fetch_by_state(UnitOfWork::STATE_DIRTY).length.should eq(1)
    @uow.tracked_objects.fetch_by_state(UnitOfWork::STATE_DIRTY)[0].object.should eq(@a_user)
    @uow.valid.should eq(true)
    @a_user.units_of_work[0].state.should eq(UnitOfWork::STATE_DIRTY)

    @a_user = User.fetch_by_id(1)
    @a_user.name.should eq('Andrew')
  end

  it "deletes objects registered for deletion when calling commit" do
    @uow.register_deleted(@a_user)

    @uow.tracked_objects.fetch_by_state(UnitOfWork::STATE_DIRTY).length.should eq(0)
    @uow.tracked_objects.fetch_by_state(UnitOfWork::STATE_DELETED)[0].object.should eq(@a_user)

    @a_user.units_of_work[0].state.should eq(UnitOfWork::STATE_DELETED)

    @uow.commit

    User[:id=>1].should be_nil
    @a_user.units_of_work.length.should eq(0)
    @uow.tracked_objects.fetch_by_state(UnitOfWork::STATE_DELETED).length.should eq(0)
  end

  it "saves new objects and marks them as dirty when calling commit" do
    pending
  end

  it "removes deleted objects from UOW when calling commit" do
    pending
  end

  it "does not affect objects when calling rollback" do
    @a_user = User.fetch_by_id(2)
    @a_user.name = 'Bartley'
    @uow.register_dirty(@a_user)
    @uow.rollback

    @uow.valid.should eq(true)
    @uow.tracked_objects.fetch_by_state(UnitOfWork::STATE_DIRTY).length.should eq(1)
    @uow.tracked_objects.fetch_by_state(UnitOfWork::STATE_DIRTY)[0].object.should eq(@a_user)
    @uow.valid.should eq(true)
    @a_user.units_of_work[0].state.should eq(UnitOfWork::STATE_DIRTY)
  end

  it "sets deleted objects to dirty and reloads dirty and deleted objects when calling rollback" do
    pending
  end

  it "does not allow calling complete if there are pending commits or rollbacks" do
    pending
  end

  it "empties, invalidates and unregisters the UOW when calling complete" do
    pending
  end

  after(:all) do
    delete_test_users
  end

end
