# frozen_string_literal: true

require_relative "test_helper"

class TestDryRunResult < Test::Unit::TestCase
  def test_basic_attributes
    result = EtcUtils::DryRunResult.new(
      content: "root:x:0:0:root:/root:/bin/bash\n",
      path: "/etc/passwd",
      changes: [],
      warnings: [],
      errors: [],
      metadata: { entry_count: 1 }
    )

    assert_equal "root:x:0:0:root:/root:/bin/bash\n", result.content
    assert_equal "/etc/passwd", result.path
    assert_equal [], result.changes
    assert_equal [], result.warnings
    assert_equal [], result.errors
    assert_equal 1, result.entry_count
  end

  def test_valid_when_no_errors
    result = EtcUtils::DryRunResult.new(
      content: "content",
      path: "/etc/passwd",
      errors: []
    )

    assert result.valid?
  end

  def test_invalid_when_has_errors
    result = EtcUtils::DryRunResult.new(
      content: "content",
      path: "/etc/passwd",
      errors: ["Duplicate UID 1000"]
    )

    refute result.valid?
  end

  def test_warnings_predicate
    result_without = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd",
      warnings: []
    )
    refute result_without.warnings?

    result_with = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd",
      warnings: ["Shell does not exist: /bin/zsh"]
    )
    assert result_with.warnings?
  end

  def test_change_summary
    changes = [
      { type: :added, name: "alice" },
      { type: :added, name: "bob" },
      { type: :modified, name: "charlie" },
      { type: :removed, name: "olduser" }
    ]

    result = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd",
      changes: changes
    )

    summary = result.change_summary
    assert_equal 2, summary[:added]
    assert_equal 1, summary[:modified]
    assert_equal 1, summary[:removed]
  end

  def test_change_summary_empty
    result = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd",
      changes: []
    )

    summary = result.change_summary
    assert_equal 0, summary[:added]
    assert_equal 0, summary[:modified]
    assert_equal 0, summary[:removed]
  end

  def test_entry_count_from_metadata
    result = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd",
      metadata: { entry_count: 42 }
    )

    assert_equal 42, result.entry_count
  end

  def test_entry_count_defaults_to_zero
    result = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd"
    )

    assert_equal 0, result.entry_count
  end

  def test_summary_valid_result
    result = EtcUtils::DryRunResult.new(
      content: "line1\nline2\n",
      path: "/etc/passwd",
      changes: [{ type: :added, name: "new" }],
      metadata: { entry_count: 2 }
    )

    summary = result.summary
    assert_match(/VALID/, summary)
    assert_match(%r{/etc/passwd}, summary)
    assert_match(/2 entries/, summary)
    assert_match(/1 added/, summary)
  end

  def test_summary_invalid_result
    result = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd",
      errors: ["Error 1", "Error 2"]
    )

    summary = result.summary
    assert_match(/INVALID/, summary)
    assert_match(/Errors: 2/, summary)
  end

  def test_summary_with_warnings
    result = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd",
      warnings: ["Warning 1"]
    )

    summary = result.summary
    assert_match(/VALID/, summary)
    assert_match(/Warnings: 1/, summary)
  end

  def test_preview
    result = EtcUtils::DryRunResult.new(
      content: "line1\nline2\nline3\n",
      path: "/etc/passwd"
    )

    preview = result.preview
    assert_match(/1: line1/, preview)
    assert_match(/2: line2/, preview)
    assert_match(/3: line3/, preview)
  end

  def test_preview_with_limit
    result = EtcUtils::DryRunResult.new(
      content: "line1\nline2\nline3\nline4\nline5\n",
      path: "/etc/passwd"
    )

    preview = result.preview(limit: 2)
    assert_match(/1: line1/, preview)
    assert_match(/2: line2/, preview)
    refute_match(/3: line3/, preview)
  end

  def test_to_h
    result = EtcUtils::DryRunResult.new(
      content: "content",
      path: "/etc/passwd",
      changes: [{ type: :added }],
      warnings: ["warn"],
      errors: [],
      metadata: { entry_count: 1 }
    )

    hash = result.to_h

    assert_equal "/etc/passwd", hash[:path]
    assert_equal true, hash[:valid]
    assert_equal 1, hash[:entry_count]
    assert_equal [{ type: :added }], hash[:changes]
    assert_equal ["warn"], hash[:warnings]
    assert_equal [], hash[:errors]
    assert_equal({ entry_count: 1 }, hash[:metadata])
  end

  def test_to_s_returns_summary
    result = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd"
    )

    assert_equal result.summary, result.to_s
  end

  def test_inspect
    result = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd",
      changes: [{ type: :added }],
      metadata: { entry_count: 5 }
    )

    inspect = result.inspect
    assert_match(/DryRunResult/, inspect)
    assert_match(%r{/etc/passwd}, inspect)
    assert_match(/valid=true/, inspect)
    assert_match(/entries=5/, inspect)
    assert_match(/changes=1/, inspect)
  end

  def test_frozen_collections
    changes = [{ type: :added }]
    warnings = ["warn"]
    errors = ["error"]
    metadata = { key: "value" }

    result = EtcUtils::DryRunResult.new(
      content: "",
      path: "/etc/passwd",
      changes: changes,
      warnings: warnings,
      errors: errors,
      metadata: metadata
    )

    assert result.changes.frozen?
    assert result.warnings.frozen?
    assert result.errors.frozen?
    assert result.metadata.frozen?
  end
end
