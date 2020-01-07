module cli

fn version_flag() Flag {
	return Flag{
		flag: .bool,
		name: 'version',
		abbrev: 'v',
		description: 'Prints version information',
	}
}

fn version_cmd() Command {
	return Command{
		name: 'version'
		description: 'Prints version information',
		execute: version_func,
		parent: 0
	}
}

fn version_func(version_cmd cli.Command) {
	cmd := version_cmd.parent
	version := '${cmd.name} v${cmd.version}'
	println(version)
}
