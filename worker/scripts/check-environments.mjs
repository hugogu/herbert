import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { unstable_readConfig } from "wrangler";

const configs = ["", "staging", "production"].map((env) =>
    unstable_readConfig({ config: "wrangler.jsonc", env }),
);

test("local, staging and production have independent databases and token issuers", () => {
    for (const key of ["name", "database_name", "database_id", "issuer"]) {
        const values = configs.map((config) => {
            if (key === "issuer") return config.vars.TOKEN_ISSUER;
            if (key === "name") return config.name;
            return config.d1_databases[0][key];
        });
        assert.equal(new Set(values).size, configs.length, key);
    }
    for (const config of configs) {
        assert.equal(config.d1_databases.length, 1);
        assert.equal(config.d1_databases[0].binding, "DB");
        assert.equal(config.d1_databases[0].migrations_dir, "migrations");
        assert.notEqual(config.d1_databases[0].remote, true);
        for (const secret of [
            "SESSION_SECRET",
            "TOKEN_ENCRYPTION_KEY",
            "APPLE_PRIVATE_KEY",
        ])
            assert.equal(config.vars[secret], undefined);
    }
});

test("staging uses a separate Apple app and each environment runs maintenance", () => {
    assert.equal(
        configs[0].vars.APPLE_CLIENT_ID,
        configs[1].vars.APPLE_CLIENT_ID,
    );
    assert.equal(
        configs[1].vars.APPLE_CLIENT_ID,
        "info.hugogu.Herbert.Staging",
    );
    assert.equal(configs[2].vars.APPLE_CLIENT_ID, "info.hugogu.Herbert");
    assert.deepEqual(configs[0].triggers.crons, []);
    for (const config of configs.slice(1))
        assert.deepEqual(config.triggers.crons, ["*/5 * * * *"]);
});

test("local scripts force local storage even with an ambient Cloudflare environment", () => {
    const { scripts } = JSON.parse(readFileSync("package.json", "utf8"));
    for (const name of ["dev", "migrate:local"]) {
        assert.match(scripts[name], /--local(?:\s|$)/);
        assert.match(scripts[name], /--env=(?:\s|$)/);
        assert.match(scripts[name], /--persist-to \.wrangler\/state/);
        assert.doesNotMatch(scripts[name], /--remote/);
    }
    for (const env of ["staging", "production"]) {
        assert.match(
            scripts[`migrate:${env}`],
            new RegExp(`--remote --env ${env}$`),
        );
        assert.match(scripts[`deploy:${env}`], new RegExp(`--env ${env}$`));
    }
    assert.equal(scripts.deploy, undefined);
    assert.equal(scripts["migrate:remote"], undefined);
});

test("edge IP limiter namespaces are isolated and CPU budgets explicit", () => {
    assert.equal(
        new Set(configs.map((config) => config.ratelimits[0].namespace_id))
            .size,
        configs.length,
    );
    for (const config of configs) {
        assert.equal(config.ratelimits[0].name, "IP_LIMITER");
        assert.deepEqual(config.ratelimits[0].simple, {
            limit: 120,
            period: 60,
        });
        assert.equal(config.limits.cpu_ms, 1000);
    }
});
