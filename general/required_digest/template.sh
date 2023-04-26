apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8simagedigests
  annotations:
    metadata.gatekeeper.sh/title: "Image Digests"
    metadata.gatekeeper.sh/version: 1.0.0
    description: >-
      Requires container images to contain a digest.
      https://kubernetes.io/docs/concepts/containers/images/
spec:
  crd:
    spec:
      names:
        kind: K8sImageDigests
      validation:
        openAPIV3Schema:
          type: object
          description: >-
            Requires container images to contain a digest.
            https://kubernetes.io/docs/concepts/containers/images/
          properties:
            exemptImages:
              description: >-
                Any container that uses an image that matches an entry in this list will be excluded
                from enforcement. Prefix-matching can be signified with `*`. For example: `my-image-*`.
                It is recommended that users use the fully-qualified Docker image name (e.g. start with a domain name)
                in order to avoid unexpectedly exempting images from an untrusted repository.
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8simagedigests
        import data.lib.exempt_container.is_exempt
        violation[{"msg": msg}] {
          container := input.review.object.spec.containers[_]
          not is_exempt(container)
          satisfied := [re_match("@[a-z0-9]+([+._-][a-z0-9]+)*:[a-zA-Z0-9=_-]+", container.image)]
          not all(satisfied)
          msg := sprintf("container <%v> uses an image without a digest <%v>", [container.name, container.image])
        }
        violation[{"msg": msg}] {
          container := input.review.object.spec.initContainers[_]
          not is_exempt(container)
          satisfied := [re_match("@[a-z0-9]+([+._-][a-z0-9]+)*:[a-zA-Z0-9=_-]+", container.image)]
          not all(satisfied)
          msg := sprintf("initContainer <%v> uses an image without a digest <%v>", [container.name, container.image])
        }
        violation[{"msg": msg}] {
          container := input.review.object.spec.ephemeralContainers[_]
          not is_exempt(container)
          satisfied := [re_match("@[a-z0-9]+([+._-][a-z0-9]+)*:[a-zA-Z0-9=_-]+", container.image)]
          not all(satisfied)
          msg := sprintf("ephemeralContainer <%v> uses an image without a digest <%v>", [container.name, container.image])
        }
      libs:
        - |
          package lib.exempt_container
          is_exempt(container) {
              exempt_images := object.get(object.get(input, "parameters", {}), "exemptImages", [])
              img := container.image
              exemption := exempt_images[_]
              _matches_exemption(img, exemption)
          }
          _matches_exemption(img, exemption) {
              not endswith(exemption, "*")
              exemption == img
          }
          _matches_exemption(img, exemption) {
              endswith(exemption, "*")
              prefix := trim_suffix(exemption, "*")
              startswith(img, prefix)
          }
