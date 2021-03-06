shared_examples "a message type" do |msg_type|

  versions = msg_type.constants.select {|x| x =~ /V[0-9]+/ }
    .map {|x| x.to_s[1..-1].to_i}

  describe ".decode" do
    context "when the current version is 1" do
      before :each do
        set_current_version(message_type, 1)
      end

      after :each do
        reset_version(message_type)
      end

      it "should return a V1 object given a flat hash" do
        data = component.send(mock_method, 1).contents
        json = Yajl::Encoder.encode(data)
        msg_obj = message_type.decode(json)
        msg_obj.class.should == message_type::V1

        message_type::V1.schema.schemas.keys do |key|
          msg_obj.send(key).should == data[key]
        end
      end

      it "should return a V1 object given a V1-encoded json" do
        data = component.send(mock_method, 1).contents

        msg_hash = {"V1" => data, "min_version" => 1}
        json = Yajl::Encoder.encode(msg_hash)

        msg_obj = message_type.decode(json)
        msg_obj.class.should == message_type::V1

        message_type::V1.schema.schemas.keys do |key|
          msg_obj.send(key).should == data[key]
        end
      end

      it "should return a V1 object given a mixed (V1-encoded + flat hash) json" do
        data = component.send(mock_method, 1).contents
        msg_hash = {
          "V1" => data,
          "min_version" => 1
        }.merge(Schemata::Helpers.deep_copy(data))
        json = Yajl::Encoder.encode(msg_hash)

        msg_obj = message_type.decode(json)
        msg_obj.class.should == message_type::V1

        message_type::V1.schema.schemas.keys do |key|
          msg_obj.send(key).should == data[key]
        end
      end

      it "should return a V1 object when given a V2-encoded json" do
        v2_hash = component.send(mock_method, 1).contents
        msg_hash = {
          "V2" => v2_hash,
          "V1" => {},
          "min_version" => 1
        }
        json = Yajl::Encoder.encode(msg_hash)

        msg_obj = message_type.decode(json)
        msg_obj.class.should == message_type::V1

        message_type::V1.schema.schemas.keys do |key|
          msg_obj.send(key).should == data[key]
        end
      end

      it "should raise an error if the input does not have the valid Schemata \
structure or a complete flash hash" do
        mock_obj = component.send(mock_method, 1)
        mock_hash = mock_obj.contents

        if num_mandatory_fields(mock_obj) > 1
          first_key = mock_hash.keys[0]
          first_value = mock_hash[first_key]

          json = Yajl::Encoder.encode({ first_key => first_value})
        else
          json = Yajl::Encoder.encode({})
        end
        expect {
          msg_obj = message_type.decode(json)
        }.to raise_error(Schemata::DecodeError)
      end
    end

    if versions.include?(2)
      context "when the current version is 2" do
        before :each do
          set_current_version(message_type, 2)
        end

        after :each do
          reset_version(message_type)
        end

        it "should raise an error given a flat hash" do
          data = component.send(mock_method, 2).contents
          json = Yajl::Encoder.encode(data)
          expect {
            msg_obj = message_type.decode(json)
          }.to raise_error(Schemata::DecodeError)
        end

        it "should return a V2 object a given a mixed (flat hash + V1-encoded) json" do
          msg_hash = component.send(mock_method, 2).contents
          v1_hash = Schemata::Helpers.deep_copy(msg_hash)
          msg_hash["V1"] = v1_hash
          msg_hash["min_version"] = 1

          json = Yajl::Encoder.encode(msg_hash)

          msg_obj = message_type.decode(json)
          msg_obj.class.should == message_type::V2

          message_type::V2.schema.schemas.keys.each do |key|
            msg_obj.send(key).should == v1_hash[key]
          end
        end

        it "should return a V2 object given a V1-encoded json" do
          v1_hash = component.send(mock_method, 1).contents
          msg_hash = {"V1" => v1_hash, 'min_version' => 1}

          json = Yajl::Encoder.encode(msg_hash)

          msg_obj = message_type.decode(json)
          msg_obj.class.should == message_type::V2

          message_type::V2.schema.schemas.keys.each do |key|
            msg_obj.send(key).should == v1_hash[key]
          end
        end

        it "should return a V2 object given a V2-encoded object" do
          data = component.send(mock_method, 2).contents
          v2_hash = Schemata::Helpers.deep_copy(data)
          msg_hash = {"V2" => v2_hash, "V1" => {}, "min_version" => 1}

          json = Yajl::Encoder.encode(msg_hash)

          msg_obj = message_type.decode(json)
          msg_obj.class.should == message_type::V2

          message_type::V2.schema.schemas.keys.each do |key|
            msg_obj.send(key).should == data[key]
          end
        end
      end
    end
  end

  # The first two versions have exceptional behavior, starting from
  # version 3, all versions should have the same unit tests
  versions.select { |x| x > 2 }.each do |version|

  end

  # Test message version types
  versions.each do |version|
    msg = msg_type::const_get("V#{version}")
    describe "V#{version}" do
      it_behaves_like "a message", msg do
        let (:message)            { message_type::const_get("V#{version}") }
        let (:message_name)       { message.to_s }
      end
    end
  end
end
