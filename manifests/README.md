# Gotchas

## Adding a new application to only one environment

The ApplicationSet as deployed only creates applications if they have a definition in the `base` directory. 
This presents a problem since any resource listed in base would immediately be created in every repository. 

In order to get around this limitation, one should create a `kustomization.yaml` that generates 0 resources, this would look like:
```yaml
# kustomization.yaml
resources: []
```


## Singleton cluster overrides

Let's say you deploy your `prod` environment to distinct regions, and these regions do not communicate.
These effectively constitute their own environment that acts as a subset of `prod`. 
They might be called e.g.

- `prod-us`
- `prod-eu-1`
- `prod-eu-2`

Ideally, we would like to configure them in such a way that they share all `prod` overrides, whilst still having regional overrides on top of that. This is a better situation than simply specifying these environments entirely separately.
